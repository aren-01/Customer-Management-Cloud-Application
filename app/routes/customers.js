const express = require("express");
const router = express.Router();

module.exports = function (db) {

  // This shows the customer table with search and pagination
  router.get("/", async (req, res) => {
    try {
      const search = (req.query.search || "").trim();

      let currentPage = parseInt(req.query.page, 10);
      if (isNaN(currentPage) || currentPage < 1) {
        currentPage = 1;
      }

      const limit = 20;
      const offset = (currentPage - 1) * limit;

      let customers = [];
      let totalCustomers = 0;

      if (search !== "") {
        if (/^\d+$/.test(search)) {
          const [countRows] = await db.execute(
            `SELECT COUNT(*) AS total
             FROM customers
             WHERE cid = ?`,
            [search]
          );

          totalCustomers = countRows[0].total;

          const [rows] = await db.execute(
            `SELECT cid, name, email, phone, address, insurance
             FROM customers
             WHERE cid = ?
             ORDER BY cid ASC
             LIMIT ${limit} OFFSET ${offset}`,
            [search]
          );

          customers = rows;

        } else {
          const searchPattern = `%${search}%`;

          const [countRows] = await db.execute(
            `SELECT COUNT(*) AS total
             FROM customers
             WHERE name LIKE ?`,
            [searchPattern]
          );

          totalCustomers = countRows[0].total;

          const [rows] = await db.execute(
            `SELECT cid, name, email, phone, address, insurance
             FROM customers
             WHERE name LIKE ?
             ORDER BY cid ASC
             LIMIT ${limit} OFFSET ${offset}`,
            [searchPattern]
          );

          customers = rows;
        }

      } else {
        const [countRows] = await db.execute(
          `SELECT COUNT(*) AS total
           FROM customers`
        );

        totalCustomers = countRows[0].total;

        const [rows] = await db.execute(
          `SELECT cid, name, email, phone, address, insurance
           FROM customers
           ORDER BY cid ASC
           LIMIT ${limit} OFFSET ${offset}`
        );

        customers = rows;
      }

      const totalPages = Math.max(Math.ceil(totalCustomers / limit), 1);

      res.render("manage-customers", {
        page: "customers",
        customers: customers,
        search: search,
        message: "",
        currentPage: currentPage,
        totalPages: totalPages
      });

    } catch (err) {
      res.status(500).send("Database error: " + err.message);
    }
  });



  // This saves edits from the Manage Customers table
  router.post("/update", async (req, res) => {
    try {
      const cid = (req.body.cid || "").trim();
      const name = (req.body.name || "").trim();
      const email = (req.body.email || "").trim();
      const phone = (req.body.phone || "").trim();
      const address = (req.body.address || "").trim();
      const insurance = (req.body.insurance || "").trim();

      if (!cid || !name || !email) {
        return res.send("Customer ID, name, and email are required.");
      }

      if (!/^\d+$/.test(cid)) {
        return res.send("Invalid Customer ID.");
      }

      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        return res.send("Invalid email format.");
      }

      if (!["verified", "unverified", "pending"].includes(insurance)) {
        return res.send("Invalid insurance value.");
      }

      if (phone.length > 25) {
        return res.send("Phone number is too long.");
      }

      if (address.length > 255) {
        return res.send("Address is too long.");
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



  // This displays the empty add customer form
  router.get("/add", (req, res) => {
    res.render("add-customer", {
      page: "add-customer",
      error: "",
      success: ""
    });
  });



  // This inserts the new customer into MySQL
  router.post("/add", async (req, res) => {
    try {
      const name = (req.body.name || "").trim();
      const email = (req.body.email || "").trim();
      const phone = (req.body.phone || "").trim();
      const address = (req.body.address || "").trim();
      const insurance = (req.body.insurance || "").trim();

      let error = "";

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
          error: error,
          success: ""
        });
      }

      const [result] = await db.execute(
        `INSERT INTO customers
         (name, email, phone, address, insurance)
         VALUES (?, ?, ?, ?, ?)`,
        [name, email, phone, address, insurance]
      );

      res.render("add-customer", {
        page: "add-customer",
        error: "",
        success: `New customer added. ID: ${result.insertId}`
      });

    } catch (err) {
      res.render("add-customer", {
        page: "add-customer",
        error: "Database error: " + err.message,
        success: ""
      });
    }
  });



  return router;
};