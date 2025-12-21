<?php

$servername = "mysql";
$username = "root";
$password = "aplusfamily";
$dbname = "db_health";

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
  die("Connection failed: " . $conn->connect_error);
}

if (isset($_POST['check'])) {
  $id = trim($_POST['ID']);

  if ($id == "") {
    echo "<script>alert('Please enter a customer ID');</script>";
  } else {
    
    $sql = "SELECT insurance FROM customers WHERE cid = '$id'";
    $result = $conn->query($sql);

    if ($result->num_rows == 0) {
      
      echo "<script>alert('Invalid customer ID');</script>";
    } else {
      $row = $result->fetch_assoc();

      if (strtolower($row['insurance']) === 'verified') {
        
        echo "<script>alert('Customer ID $id is already verified');</script>";
      } else {
       
        $update = "UPDATE customers SET insurance='verified' WHERE cid='$id'";
        if ($conn->query($update) === TRUE) {
          echo "<script>alert('Valid insurance found for user ID $id. Status updated to verified.');</script>";
        } else {
          echo "<script>alert('Database update error: " . $conn->error . "');</script>";
        }
      }
    }
  }
}

$conn->close();
?>


<style>
  table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 20px;
  }
  th, td {
    border: 1px solid #ccc;
    padding: 10px;
    text-align: left;
  }
  th { background: #f4f4f4; }
  input, textarea, select {
    width: 100%;
    padding: 6px;
    box-sizing: border-box;
  }
</style>



<section class="content-area">
  <form method="POST" action="">
    <h5>Type Customer ID:</h5>
    <input type="text" name="ID" style="width: 115px">
    <button type="submit" name="check" style="margin-top: 10px; padding: 6px 10px;">Check</button>
  </form>
</section>

