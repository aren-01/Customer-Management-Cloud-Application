const express = require("express");
const router = express.Router();

module.exports = function (db) {

  // This shows the appointment table with search and pagination
  router.get("/", async (req, res) => {
    try {
      const search = (req.query.search || "").trim();
      const filterType = req.query.filter_type === "cid" ? "cid" : "aid";

      let currentPage = parseInt(req.query.page, 10);
      if (isNaN(currentPage) || currentPage < 1) {
        currentPage = 1;
      }

      const limit = 20;
      const offset = (currentPage - 1) * limit;

      let appointments = [];
      let totalAppointments = 0;

      if (search !== "" && /^\d+$/.test(search)) {

        if (filterType === "cid") {
          const [countRows] = await db.execute(
            `SELECT COUNT(*) AS total
             FROM appointments
             WHERE cid = ?`,
            [search]
          );

          totalAppointments = countRows[0].total;

          const [rows] = await db.execute(
            `SELECT aid, cid, date, status, payment
             FROM appointments
             WHERE cid = ?
             ORDER BY aid ASC
             LIMIT ${limit} OFFSET ${offset}`,
            [search]
          );

          appointments = rows;

        } else {
          const [countRows] = await db.execute(
            `SELECT COUNT(*) AS total
             FROM appointments
             WHERE aid = ?`,
            [search]
          );

          totalAppointments = countRows[0].total;

          const [rows] = await db.execute(
            `SELECT aid, cid, date, status, payment
             FROM appointments
             WHERE aid = ?
             ORDER BY aid ASC
             LIMIT ${limit} OFFSET ${offset}`,
            [search]
          );

          appointments = rows;
        }

      } else {
        const [countRows] = await db.execute(
          `SELECT COUNT(*) AS total
           FROM appointments`
        );

        totalAppointments = countRows[0].total;

        const [rows] = await db.execute(
          `SELECT aid, cid, date, status, payment
           FROM appointments
           ORDER BY aid ASC
           LIMIT ${limit} OFFSET ${offset}`
        );

        appointments = rows;
      }

      const totalPages = Math.max(Math.ceil(totalAppointments / limit), 1);

      res.render("manage-appointments", {
        page: "appointments",
        appointments: appointments,
        search: search,
        filterType: filterType,
        message: "",
        currentPage: currentPage,
        totalPages: totalPages
      });

    } catch (err) {
      res.status(500).send("Database error: " + err.message);
    }
  });



  // This saves edits from the Manage Appointments table
  router.post("/update", async (req, res) => {
    try {
      const aid = (req.body.aid || "").trim();
      const cid = (req.body.cid || "").trim();
      const date = (req.body.date || "").trim();
      const status = (req.body.status || "").trim();
      const payment = (req.body.payment || "").trim();

      if (!aid || !cid || !date) {
        return res.send("Appointment ID, Customer ID, and date are required.");
      }

      if (!/^\d+$/.test(aid)) {
        return res.send("Invalid Appointment ID.");
      }

      if (!/^\d+$/.test(cid)) {
        return res.send("Invalid Customer ID.");
      }

      if (!["upcoming", "successful", "unsuccessful", "canceled"].includes(status)) {
        return res.send("Invalid appointment status.");
      }

      if (!["successful", "unsuccessful"].includes(payment)) {
        return res.send("Invalid payment value.");
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



  // This only displays the empty schedule form
  router.get("/schedule", (req, res) => {
    res.render("schedule", {
      page: "schedule",
      error: "",
      success: ""
    });
  });



  // This inserts a new appointment into MySQL
  router.post("/schedule", async (req, res) => {
    try {
      const cid = (req.body.cid || "").trim();
      const date = (req.body.date || "").trim();
      const status = (req.body.status || "").trim();
      const payment = (req.body.payment || "").trim();

      let error = "";

      if (!cid || !date) {
        error = "Customer ID and Date cannot be empty.";
      } else if (!/^\d+$/.test(cid)) {
        error = "Invalid Customer ID.";
      } else if (!["upcoming", "successful", "unsuccessful", "canceled"].includes(status)) {
        error = "Invalid status value.";
      } else if (!["successful", "unsuccessful"].includes(payment)) {
        error = "Invalid payment value.";
      }

      if (error) {
        return res.render("schedule", {
          page: "schedule",
          error: error,
          success: ""
        });
      }

      const [result] = await db.execute(
        `INSERT INTO appointments
         (cid, date, status, payment)
         VALUES (?, ?, ?, ?)`,
        [cid, date, status, payment]
      );

      res.render("schedule", {
        page: "schedule",
        error: "",
        success: `New appointment scheduled. ID: ${result.insertId}`
      });

    } catch (err) {
      res.render("schedule", {
        page: "schedule",
        error: "Database error: " + err.message,
        success: ""
      });
    }
  });



  return router;
};