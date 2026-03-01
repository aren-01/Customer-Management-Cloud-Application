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
    $name     = trim($_POST['name']);
    $email    = trim($_POST['email']);
    $phone    = trim($_POST['phone']);
    $address  = trim($_POST['address']);
    $insurance= trim($_POST['insurance']);

    
    if (empty($name) || empty($email)) {
        $error = "Name and Email cannot be empty.";
    } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $error = "Invalid email format.";
    } elseif (!in_array($insurance, ['verified','unverified','pending'])) {
        $error = "Invalid insurance value.";
    } elseif (strlen($phone) > 25) {
        $error = "Phone number is too long.";
    } elseif (strlen($address) > 255) {
        $error = "Address is too long.";
    } else {
        
        $stmt = $conn->prepare("INSERT INTO customers (name, email, phone, address, insurance) VALUES (?, ?, ?, ?, ?)");
        if (!$stmt) {
            $error = "SQL Error (prepare): " . $conn->error;
        } else {
            $stmt->bind_param("sssss", $name, $email, $phone, $address, $insurance);
            if ($stmt->execute()) {
                $success = "New customer added. (ID: " . $stmt->insert_id . ")";
            } else {
                $error = "SQL Error (insert): " . $conn->error;
            }
            $stmt->close();
        }
    }
}
?>

 <style>
       
        form { max-width: 500px; margin: auto; background: #f9f9f9; padding: 20px; border-radius: 8px; }
        label { display: block; margin-top: 10px; }
        input, textarea, select { width: 100%; padding: 8px; margin-top: 5px; }
        button { margin-top: 15px; padding: 10px 15px; }
        .error { color: red; margin-top: 10px; }
        .success { color: green; margin-top: 10px; }
    </style>

<h5>Add New Customer</h5>

<?php if (!empty($error)) echo "<p class='error'>$error</p>"; ?>
<?php if (!empty($success)) echo "<p class='success'>$success</p>"; ?>

<form method="post">
    <label>Name and Surname:</label>
    <input type="text" name="name" required>

    <label>Email:</label>
    <input type="email" name="email" required>

    <label>Phone:</label>
    <input type="text" name="phone">

    <label>Address:</label>
    <textarea name="address"></textarea>

    <label>Insurance:</label>
    <select name="insurance">
        <option value="verified">Verified</option>
        <option value="unverified">Unverified</option>
        <option value="pending">Pending</option>
    </select>

    <button type="submit">Add Customer</button>
</form>

<?php 
$conn->close();
?>