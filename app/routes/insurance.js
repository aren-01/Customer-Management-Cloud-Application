

const express = require("express");
const router = express.Router();

module.exports = function (db) {


  // This only displays the form

  router.get("/verify", (req, res) => {
    res.render("verify", {
      page: "verify",
      message: "",
      error: "",
      success: "",
    });
  });



  // This checks the customer and updates insurance to verified
  // Please note that it verifies every insurance by default. In a real project, it has to check the insurance with an API. 
  // Change the code below to use an API from an insurance company.

  router.post("/verify", async (req, res) => {
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
        `SELECT cid, insurance
         FROM customers
         WHERE cid = ?`,
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
        `UPDATE customers
         SET insurance = 'verified'
         WHERE cid = ?`,
        [cid]
      );

      res.render("verify", {
        page: "verify",
        message: "",
        error: "",
        success: `Valid insurance found for user ID ${cid}. Their status updated to verified!`,
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


  return router;
};