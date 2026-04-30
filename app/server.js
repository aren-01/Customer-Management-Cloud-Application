const crypto = require("crypto");
const expressLayouts = require("express-ejs-layouts");
const express = require("express");
const mysql = require("mysql2/promise");
const path = require("path");
const session = require("express-session");
const { createRemoteJWKSet, jwtVerify } = require("jose");

const app = express();

const requiredEnvVars = [
  "APP_BASE_URL",
  "COGNITO_DOMAIN",
  "COGNITO_USER_POOL_ID",
  "COGNITO_CLIENT_ID",
  "COGNITO_CLIENT_SECRET",
  "SESSION_SECRET",
  "CLOUDFRONT_SECRET", // Added this here
  "DB_HOST",
  "DB_USER",
  "DB_PASS",
  "DB_NAME",
];

const missingEnvVars = requiredEnvVars.filter((name) => !process.env[name]);
if (missingEnvVars.length > 0) {
  throw new Error(`Missing required environment variables: ${missingEnvVars.join(", ")}`);
}

const APP_BASE_URL = process.env.APP_BASE_URL.replace(/\/$/, "");
const AWS_REGION = process.env.AWS_REGION || "us-east-1";
const COGNITO_DOMAIN = process.env.COGNITO_DOMAIN.replace(/\/$/, "");
const COGNITO_USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;
const COGNITO_CLIENT_ID = process.env.COGNITO_CLIENT_ID;
const COGNITO_CLIENT_SECRET = process.env.COGNITO_CLIENT_SECRET;
const COGNITO_CALLBACK_URL = process.env.COGNITO_CALLBACK_URL || `${APP_BASE_URL}/auth/callback`;
const COGNITO_LOGOUT_URL = process.env.COGNITO_LOGOUT_URL || `${APP_BASE_URL}/`;
const COGNITO_ISSUER = `https://cognito-idp.${AWS_REGION}.amazonaws.com/${COGNITO_USER_POOL_ID}`;
const COGNITO_SCOPES = "openid email profile";
const COGNITO_JWKS = createRemoteJWKSet(new URL(`${COGNITO_ISSUER}/.well-known/jwks.json`));
const CLOUDFRONT_SECRET = process.env.CLOUDFRONT_SECRET; // Grab secret from ENV

// Trust CloudFront/ALB proxy headers.

app.set("trust proxy", true);


app.use((req, res, next) => {
  req.headers["x-forwarded-proto"] = "https";
  next();
});

// Health route for the ALB target group. Do not protect this with Cognito or host verification.
app.get("/health", (req, res) => {
  res.status(200).send("OK");
});

// Database information
const db = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  port: Number(process.env.DB_PORT || 3306),
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

// Setup
app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));
app.use(expressLayouts);
app.set("layout", "layout");

app.use(express.urlencoded({ extended: true }));

app.use(
  session({
    name: process.env.SESSION_COOKIE_NAME || "customerapp.sid",
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.SESSION_COOKIE_SECURE === "true",
      maxAge: 60 * 60 * 1000,
    },
  })
);

app.use((req, res, next) => {
  res.locals.page = "";
  res.locals.message = "";
  res.locals.error = "";
  res.locals.success = "";
  res.locals.user = req.session.user || null;
  next();
});

// Replaced Host verification with Secret verification
function requireCloudFrontSecret(req, res, next) {
  const incomingSecret = req.headers["x-cloudfront-secret"];

  if (incomingSecret === CLOUDFRONT_SECRET) {
    return next();
  }

  console.warn(`Blocked request with invalid secret. path=${req.originalUrl}`);
  return res.status(403).send("Forbidden. Please use the CloudFront application URL.");
}

function safeReturnTo(returnTo) {
  if (!returnTo || typeof returnTo !== "string") {
    return "/";
  }

  if (!returnTo.startsWith("/") || returnTo.startsWith("//")) {
    return "/";
  }

  return returnTo;
}

function buildCognitoLoginUrl(state) {
  const params = new URLSearchParams({
    client_id: COGNITO_CLIENT_ID,
    response_type: "code",
    scope: COGNITO_SCOPES,
    redirect_uri: COGNITO_CALLBACK_URL,
    state,
  });

  return `${COGNITO_DOMAIN}/login?${params.toString()}`;
}

function buildCognitoLogoutUrl() {
  const params = new URLSearchParams({
    client_id: COGNITO_CLIENT_ID,
    logout_uri: COGNITO_LOGOUT_URL,
  });

  return `${COGNITO_DOMAIN}/logout?${params.toString()}`;
}

async function exchangeCodeForTokens(code) {
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: COGNITO_CLIENT_ID,
    code,
    redirect_uri: COGNITO_CALLBACK_URL,
  });

  const basicAuth = Buffer.from(`${COGNITO_CLIENT_ID}:${COGNITO_CLIENT_SECRET}`).toString("base64");

  const response = await fetch(`${COGNITO_DOMAIN}/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${basicAuth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Cognito token exchange failed: ${response.status} ${errorText}`);
  }

  return response.json();
}

async function verifyIdToken(idToken) {
  const { payload } = await jwtVerify(idToken, COGNITO_JWKS, {
    issuer: COGNITO_ISSUER,
    audience: COGNITO_CLIENT_ID,
  });

  return payload;
}

function requireAuth(req, res, next) {
  if (req.session.user) {
    return next();
  }

  return res.redirect(`/login?returnTo=${encodeURIComponent(req.originalUrl)}`);
}

// Only allow normal app traffic when the request has the CloudFront secret header
app.use(requireCloudFrontSecret);

// This lets Express use files from the public folder.
app.use(express.static(path.join(__dirname, "public")));

app.get("/login", (req, res) => {
  const state = crypto.randomBytes(32).toString("hex");

  req.session.oauthState = state;
  req.session.returnTo = safeReturnTo(req.query.returnTo || "/");

  res.redirect(buildCognitoLoginUrl(state));
});

app.get("/auth/callback", async (req, res) => {
  try {
    const { code, state, error, error_description } = req.query;

    if (error) {
      return res.status(401).send(`Cognito login failed: ${error_description || error}`);
    }

    if (!code || !state || state !== req.session.oauthState) {
      return res.status(400).send("Invalid Cognito callback state.");
    }

    const tokens = await exchangeCodeForTokens(code);
    const idTokenPayload = await verifyIdToken(tokens.id_token);

    req.session.user = {
      sub: idTokenPayload.sub,
      email: idTokenPayload.email,
      name: idTokenPayload.name || idTokenPayload.email,
    };

    delete req.session.oauthState;

    const returnTo = safeReturnTo(req.session.returnTo || "/");
    delete req.session.returnTo;

    res.redirect(returnTo);
  } catch (err) {
    console.error(err);
    res.status(500).send("Authentication error: " + err.message);
  }
});

app.get("/logout", (req, res) => {
  req.session.destroy(() => {
    res.clearCookie(process.env.SESSION_COOKIE_NAME || "customerapp.sid");
    res.redirect(buildCognitoLogoutUrl());
  });
});

// Everything below this line requires a successful Cognito sign-in.
app.use(requireAuth);

// Route files
const customerRoutes = require("./routes/customers");
const appointmentRoutes = require("./routes/appointments");
const reportRoutes = require("./routes/reports");
const settingsRoutes = require("./routes/settings");

app.use("/customers", customerRoutes(db));
app.use("/appointments", appointmentRoutes(db));
app.use("/reports", reportRoutes(db));
app.use("/settings", settingsRoutes(db));

// Main page
app.get("/", (req, res) => {
  res.render("introduction", {
    page: "home",
  });
});

// Manage Customers page
app.get("/customers", async (req, res) => {
  try {
    const search = req.query.search || "";
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    const limit = 20;
    const offset = (page - 1) * limit;

    let customers;
    let totalRows = 0;

    if (search.trim() !== "") {
      if (/^[0-9]+$/.test(search)) {
        const [countRows] = await db.execute(
          "SELECT COUNT(*) AS total FROM customers WHERE cid = ?",
          [search]
        );
        totalRows = countRows[0].total;

        const [rows] = await db.execute(
          `SELECT cid, name, email, phone, address, insurance
           FROM customers
           WHERE cid = ?
           ORDER BY cid ASC
           LIMIT ? OFFSET ?`,
          [search, limit, offset]
        );
        customers = rows;
      } else {
        const [countRows] = await db.execute(
          "SELECT COUNT(*) AS total FROM customers WHERE name LIKE ?",
          [`%${search}%`]
        );
        totalRows = countRows[0].total;

        const [rows] = await db.execute(
          `SELECT cid, name, email, phone, address, insurance
           FROM customers
           WHERE name LIKE ?
           ORDER BY cid ASC
           LIMIT ? OFFSET ?`,
          [`%${search}%`, limit, offset]
        );
        customers = rows;
      }
    } else {
      const [countRows] = await db.execute(
        "SELECT COUNT(*) AS total FROM customers"
      );
      totalRows = countRows[0].total;

      const [rows] = await db.execute(
        `SELECT cid, name, email, phone, address, insurance
         FROM customers
         ORDER BY cid ASC
         LIMIT ? OFFSET ?`,
        [limit, offset]
      );
      customers = rows;
    }

    const totalPages = Math.ceil(totalRows / limit) || 1;

    res.render("manage-customers", {
      page: "customers",
      customers,
      search,
      currentPage: page,
      totalPages,
      error: "",
      success: "",
    });
  } catch (err) {
    res.status(500).send("Database error: " + err.message);
  }
});

// Update Customer page
app.post("/customers/update", async (req, res) => {
  try {
    const { cid, name, email, phone, address, insurance } = req.body;

    if (!cid || !name || !email) {
      return res.send("Customer ID, name, and email are required.");
    }

    if (!["verified", "unverified", "pending"].includes(insurance)) {
      return res.send("Invalid insurance value.");
    }

    await db.execute(
      `UPDATE customers
       SET name = ?, email = ?, phone = ?, address = ?, insurance = ?
       WHERE cid = ?`,
      [name, email, phone, address, insurance, cid]
    );

    res.redirect("/customers");
  } catch (err) {
    res.status(500).send("Database error: " + err.message);
  }
});

// Add Customer page
app.get("/customers/add", (req, res) => {
  res.render("add-customer", {
    page: "add-customer",
    error: "",
    success: "",
  });
});

// Add Customer submit
app.post("/customers/add", async (req, res) => {
  try {
    const name = (req.body.name || "").trim();
    const email = (req.body.email || "").trim();
    const phone = (req.body.phone || "").trim();
    const address = (req.body.address || "").trim();
    const insurance = (req.body.insurance || "").trim();

    let error = "";
    let success = "";

    if (!name || !email) {
      error = "Name and Email cannot be empty.";
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      error = "Invalid email format.";
    } else if (!["verified", "unverified", "pending"].includes(insurance)) {
      error = "Invalid insurance value.";
    } else if (phone.length > 25) {
      error = "Phone number is too long.";
    } else if (address.length > 255) {
      error = "Address is too long.";
    }

    if (error) {
      return res.render("add-customer", {
        page: "add-customer",
        error,
        success: "",
      });
    }

    const [result] = await db.execute(
      `INSERT INTO customers
       (name, email, phone, address, insurance)
       VALUES (?, ?, ?, ?, ?)`,
      [name, email, phone, address, insurance]
    );

    success = `New customer added. ID: ${result.insertId}`;

    res.render("add-customer", {
      page: "add-customer",
      error: "",
      success,
    });
  } catch (err) {
    res.render("add-customer", {
      page: "add-customer",
      error: "Database error: " + err.message,
      success: "",
    });
  }
});

// Manage Appointments page
app.get("/appointments", async (req, res) => {
  try {
    const search = req.query.search || "";
    const filterType = req.query.filter_type || "aid";
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    const limit = 20;
    const offset = (page - 1) * limit;

    let appointments;
    let totalRows = 0;

    if (search.trim() !== "" && /^[0-9]+$/.test(search)) {
      if (filterType === "cid") {
        const [countRows] = await db.execute(
          "SELECT COUNT(*) AS total FROM appointments WHERE cid = ?",
          [search]
        );
        totalRows = countRows[0].total;

        const [rows] = await db.execute(
          `SELECT aid, cid, date, status, payment
           FROM appointments
           WHERE cid = ?
           ORDER BY aid ASC
           LIMIT ? OFFSET ?`,
          [search, limit, offset]
        );
        appointments = rows;
      } else {
        const [countRows] = await db.execute(
          "SELECT COUNT(*) AS total FROM appointments WHERE aid = ?",
          [search]
        );
        totalRows = countRows[0].total;

        const [rows] = await db.execute(
          `SELECT aid, cid, date, status, payment
           FROM appointments
           WHERE aid = ?
           ORDER BY aid ASC
           LIMIT ? OFFSET ?`,
          [search, limit, offset]
        );
        appointments = rows;
      }
    } else {
      const [countRows] = await db.execute(
        "SELECT COUNT(*) AS total FROM appointments"
      );
      totalRows = countRows[0].total;

      const [rows] = await db.execute(
        `SELECT aid, cid, date, status, payment
         FROM appointments
         ORDER BY aid ASC
         LIMIT ? OFFSET ?`,
        [limit, offset]
      );
      appointments = rows;
    }

    const totalPages = Math.ceil(totalRows / limit) || 1;

    res.render("manage-appointments", {
      page: "appointments",
      appointments,
      search,
      filterType,
      currentPage: page,
      totalPages,
    });
  } catch (err) {
    res.status(500).send("Database error: " + err.message);
  }
});

// Update Appointment
app.post("/appointments/update", async (req, res) => {
  try {
    const { aid, cid, date, status, payment } = req.body;

    if (!aid || !cid || !date) {
      return res.send("Appointment ID, Customer ID, and date are required.");
    }

    if (!["upcoming", "successful", "unsuccessful", "canceled"].includes(status)) {
      return res.send("Invalid appointment status.");
    }

    if (!["successful", "unsuccessful"].includes(payment)) {
      return res.send("Invalid payment status.");
    }

    await db.execute(
      `UPDATE appointments
       SET cid = ?, date = ?, status = ?, payment = ?
       WHERE aid = ?`,
      [cid, date, status, payment, aid]
    );

    res.redirect("/appointments");
  } catch (err) {
    res.status(500).send("Database error: " + err.message);
  }
});

// Schedule Appointment page
app.get("/appointments/schedule", (req, res) => {
  res.render("schedule", {
    page: "schedule",
    error: "",
    success: "",
  });
});

// Schedule Appointment submit
app.post("/appointments/schedule", async (req, res) => {
  try {
    const cid = (req.body.cid || "").trim();
    const date = (req.body.date || "").trim();
    const status = (req.body.status || "").trim();
    const payment = (req.body.payment || "").trim();

    let error = "";
    let success = "";

    if (!cid || !date) {
      error = "Customer ID and Date cannot be empty.";
    } else if (!["upcoming", "successful", "unsuccessful", "canceled"].includes(status)) {
      error = "Invalid status value.";
    } else if (!["successful", "unsuccessful"].includes(payment)) {
      error = "Invalid payment value.";
    }

    if (error) {
      return res.render("schedule", {
        page: "schedule",
        error,
        success: "",
      });
    }

    const [result] = await db.execute(
      `INSERT INTO appointments
       (cid, date, status, payment)
       VALUES (?, ?, ?, ?)`,
      [cid, date, status, payment]
    );

    success = `New appointment scheduled. ID: ${result.insertId}`;

    res.render("schedule", {
      page: "schedule",
      error: "",
      success,
    });
  } catch (err) {
    res.render("schedule", {
      page: "schedule",
      error: "Database error: " + err.message,
      success: "",
    });
  }
});

// Verify Insurance page
app.get("/insurance/verify", (req, res) => {
  res.render("verify", {
    page: "verify",
    message: "",
    error: "",
    success: "",
  });
});

// Verify Insurance submit
app.post("/insurance/verify", async (req, res) => {
  try {
    const cid = (req.body.cid || "").trim();

    if (!cid) {
      return res.render("verify", {
        page: "verify",
        message: "",
        error: "Please enter a customer ID.",
        success: "",
      });
    }

    const [customers] = await db.execute(
      "SELECT cid, insurance FROM customers WHERE cid = ?",
      [cid]
    );

    if (customers.length === 0) {
      return res.render("verify", {
        page: "verify",
        message: "",
        error: "Invalid customer ID.",
        success: "",
      });
    }

    const customer = customers[0];

    if ((customer.insurance || "").toLowerCase() === "verified") {
      return res.render("verify", {
        page: "verify",
        message: "",
        error: "",
        success: `Customer ID ${cid} is already verified.`,
      });
    }

    await db.execute(
      "UPDATE customers SET insurance = 'verified' WHERE cid = ?",
      [cid]
    );

    res.render("verify", {
      page: "verify",
      message: "",
      error: "",
      success: `Valid insurance found for user ID ${cid}. Status updated to verified.`,
    });
  } catch (err) {
    res.render("verify", {
      page: "verify",
      message: "",
      error: "Database error: " + err.message,
      success: "",
    });
  }
});

// Start server
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Expected public URL: ${APP_BASE_URL}`);
});
