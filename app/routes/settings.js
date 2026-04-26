
const express = require("express");

const router = express.Router();

function sqlEscape(value) {
  if (value === null || value === undefined) {
    return "NULL";
  }

  if (value instanceof Date) {
    return `"${value.toISOString().slice(0, 19).replace("T", " ")}"`;
  }

  return `"${String(value)
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n")
    .replace(/\r/g, "\\r")}"`;
}

module.exports = function (db) {


  // This displays the database download button

  router.get("/", (req, res) => {
    res.render("settings", {
      page: "settings",
      error: "",
      success: "",
    });
  });



  // This generates and downloads a .sql file

  router.post("/download-sql", async (req, res) => {
    try {
      const [tablesResult] = await db.execute("SHOW TABLES");

      let sqlBackup = "";

      for (const tableRow of tablesResult) {
        const tableName = Object.values(tableRow)[0];

        const [createTableRows] = await db.execute(
          `SHOW CREATE TABLE \`${tableName}\``
        );

        const createTableSql = createTableRows[0]["Create Table"];

        sqlBackup += `DROP TABLE IF EXISTS \`${tableName}\`;\n\n`;
        sqlBackup += `${createTableSql};\n\n`;

        const [rows] = await db.execute(
          `SELECT * FROM \`${tableName}\``
        );

        for (const row of rows) {
          const columns = Object.keys(row)
            .map(column => `\`${column}\``)
            .join(", ");

          const values = Object.values(row)
            .map(value => sqlEscape(value))
            .join(", ");

          sqlBackup += `INSERT INTO \`${tableName}\` (${columns}) VALUES (${values});\n`;
        }

        sqlBackup += "\n\n";
      }

      res.setHeader("Content-Type", "application/sql");
      res.setHeader(
        "Content-Disposition",
        'attachment; filename="backup.sql"'
      );

      res.send(sqlBackup);

    } catch (err) {
      res.render("settings", {
        page: "settings",
        error: "Database backup error: " + err.message,
        success: "",
      });
    }
  });



  return router;
};