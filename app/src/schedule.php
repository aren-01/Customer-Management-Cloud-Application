<?php
$servername = "mysql";
$username = "root";
$password = "aplusfamily";
$dbname   = "db_health";

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}


$error = "";
$success = "";


if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $cid     = trim($_POST['cid']);
    $date    = trim($_POST['date']);
    $status    = trim($_POST['status']);
    $payment  = trim($_POST['payment']);
   

   
    if (empty($cid) || empty($date)) {
        $error = "Customer ID and Date cannot be empty.";
    } elseif (!in_array($status, ['upcoming','successful','unsuccessful','canceled'])) {
        $error = "Invalid status value.";
		} elseif (!in_array($payment, ['successful','unsuccessful'])) {
        $error = "Invalid status value.";
    } else {
        
        $stmt = $conn->prepare("INSERT INTO appointments (cid, date, status, payment) VALUES (?, ?, ?, ?)");
        if (!$stmt) {
            $error = "SQL Error (prepare): " . $conn->error;
        } else {
            $stmt->bind_param("ssss", $cid, $date, $status, $payment);
            if ($stmt->execute()) {
                $success = "New appointment scheduled. (ID: " . $stmt->insert_id . ")";
            } else {
                $error = "SQL Error (insert): " . $conn->error;
            }
            $stmt->close();
        }
    }
}
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
	
	form { max-width: 500px; margin: auto; background: #f9f9f9; padding: 20px; border-radius: 8px; }
        label { display: block; margin-top: 10px; }
        input, textarea, select { width: 100%; padding: 8px; margin-top: 5px; }
        button { margin-top: 15px; padding: 10px 15px; }
        .error { color: red; margin-top: 10px; }
        .success { color: green; margin-top: 10px; }
  </style>

<?php if (!empty($error)) echo "<p class='error'>$error</p>"; ?>
<?php if (!empty($success)) echo "<p class='success'>$success</p>"; ?>
<h5> Schedule New Appointment</h5>
    <form method="post">
    <label>Customer ID:</label>
    <input type="text" name="cid" required>

    <label>Appointment Date:</label>
    <input type="date" name="date" required>

    <label>Appointment Status:</label>
    <select name="status">
        <option value="upcoming">Upcoming</option>
        <option value="successful">Successful</option>
        <option value="unsuccessful">Unsuccessful</option>
		<option value="canceled">Canceled</option>
    </select>

    <label>Payment</label>
     <select name="payment">
        <option value="successful">Successful</option>
        <option value="unsuccessful">Unsuccessful</option>
    </select>

   

    <button type="submit">Schedule Appointment</button>
</form>


<?php 
$conn->close();
?>