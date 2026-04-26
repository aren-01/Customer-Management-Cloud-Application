
const express = require("express");
const PDFDocument = require("pdfkit");

const router = express.Router();

module.exports = function (db) {


  // This displays the form where user enters appointment ID

  router.get("/", (req, res) => {
    res.render("report", {
      page: "report",
      error: "",
    });
  });



  // create and download a PDF report
  // Important note: pdfkit must be installed

  router.post("/create", async (req, res) => {
    try {
      const aid = (req.body.aid || "").trim();

      if (!aid) {
        return res.render("report", {
          page: "report",
          error: "Please enter an appointment ID.",
        });
      }

      const [appointments] = await db.execute(
        `SELECT aid, cid, date, status, payment
         FROM appointments
         WHERE aid = ?`,
        [aid]
      );

      if (appointments.length === 0) {
        return res.render("report", {
          page: "report",
          error: "Invalid appointment ID.",
        });
      }

      const appointment = appointments[0];

      const [customers] = await db.execute(
        `SELECT cid, name, email, phone, address, insurance
         FROM customers
         WHERE cid = ?`,
        [appointment.cid]
      );

      if (customers.length === 0) {
        return res.render("report", {
          page: "report",
          error: "Customer not found for this appointment.",
        });
      }

      const customer = customers[0];

      const filename = `Appointment_Report_AID_${aid}.pdf`;

      res.setHeader("Content-Type", "application/pdf");
      res.setHeader(
        "Content-Disposition",
        `attachment; filename="${filename}"`
      );

      const doc = new PDFDocument({
        margin: 50,
      });

      doc.pipe(res);

      doc
        .fontSize(18)
        .text("A+ Family Healthcare Appointment Report", {
          align: "center",
        });

      doc.moveDown();

      doc
        .fontSize(14)
        .text("Customer Information", {
          underline: true,
        });

      doc.moveDown(0.5);

      doc.fontSize(12);
      doc.text(`Customer ID: ${customer.cid}`);
      doc.text(`Name: ${customer.name}`);
      doc.text(`Email: ${customer.email}`);
      doc.text(`Phone: ${customer.phone || ""}`);
      doc.text(`Address: ${customer.address || ""}`);
      doc.text(`Insurance: ${customer.insurance}`);

      doc.moveDown();

      doc
        .fontSize(14)
        .text("Appointment Information", {
          underline: true,
        });

      doc.moveDown(0.5);

      doc.fontSize(12);
      doc.text(`Appointment ID: ${appointment.aid}`);
      doc.text(`Date: ${appointment.date}`);
      doc.text(`Status: ${appointment.status}`);
      doc.text(`Payment: ${appointment.payment}`);

      doc.end();

    } catch (err) {
      res.render("report", {
        page: "report",
        error: "Database or PDF error: " + err.message,
      });
    }
  });



  return router;
};