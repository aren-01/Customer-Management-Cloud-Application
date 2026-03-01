<?php
$servername = "mysql";
$username = "root"; 
$password = "aplusfamily"; 
$dbname   = "db_health";

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}


$search = "";
$search_sql = "";
if (isset($_GET['search']) && trim($_GET['search']) !== "") {
    $search = trim($_GET['search']);
    if (ctype_digit($search)) {
        $search_sql = "WHERE cid = " . (int)$search;
    } else {
        $search_sql = "WHERE name LIKE CONCAT('%', ?, '%')";
    }
}


if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST['save'])) {
    $cid = $_POST['cid'];
    $name = $_POST['name'];
    $email = $_POST['email'];
    $phone = $_POST['phone'];
    $address = $_POST['address'];
    $insurance = $_POST['insurance'];

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        echo "<script>alert('Invalid email');</script>";
    } else {
        $stmt2 = $conn->prepare("UPDATE customers SET name=?, email=?, phone=?, address=?, insurance=? WHERE cid=?");
        $stmt2->bind_param("sssssi", $name, $email, $phone, $address, $insurance, $cid);
        $stmt2->execute();
        $stmt2->close();
    }
}


$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 20; 
if ($limit < 1) { $limit = 10; }

$page = isset($_GET['p']) ? (int)$_GET['p'] : 1; 
if ($page < 1) { $page = 1; } 

$total_sql = "SELECT COUNT(*) AS total FROM customers " . ($search_sql ? $search_sql : "");
$total_stmt = $conn->prepare($total_sql);
if ($search_sql && !ctype_digit($search)) {
    $total_stmt->bind_param("s", $search);
}
$total_stmt->execute();
$total_result = $total_stmt->get_result();
$total_row = $total_result->fetch_assoc();
$total_records = (int)$total_row['total'];
$total_pages = max(1, (int)ceil($total_records / $limit));

if ($page > $total_pages) { $page = $total_pages; } 
$offset = ($page - 1) * $limit;


$sql = "SELECT cid, name, email, phone, address, insurance 
        FROM customers 
        " . ($search_sql ? $search_sql : "") . " 
        ORDER BY cid ASC 
        LIMIT ? OFFSET ?";

$stmt = $conn->prepare($sql);
if ($search_sql && !ctype_digit($search)) {
    $stmt->bind_param("sii", $search, $limit, $offset);
} else {
    $stmt->bind_param("ii", $limit, $offset);
}
$stmt->execute();
$result = $stmt->get_result();

if (isset($_GET['list']) && $_GET['list'] == '1') {
    header("Content-Type: application/json; charset=UTF-8");
    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    echo json_encode($data);
    $stmt->close();
    $conn->close();
    exit;
}

?>

<style>
  table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
  th, td { border: 1px solid #ccc; padding: 10px; text-align: left; }
  th { background: #f4f4f4; }
  input, textarea, select { width: 100%; padding: 6px; box-sizing: border-box; }
  .pagination a { margin-right: 8px; text-decoration: none; }
  button { padding: 6px 10px; cursor: pointer; }

  /* 🎯 Aynı search bar tasarımı */
  .search-bar {
    margin-bottom: 15px;
    padding: 10px;
  }

  .search-form {
    display: flex;
    align-items: center;
    flex-wrap: nowrap;
    gap: 10px;
  }

  .search-form input[type="text"] {
    flex: 1;
    max-width: 350px;
    padding: 6px 8px;
    height: 32px;
    box-sizing: border-box;
  }

  .search-form button {
    padding: 6px 10px;
    height: 32px;
  }
</style>

<h5>Manage Customers</h5>

<div class="search-bar">
  <form method="get" action="main.php" class="search-form">
    <input type="hidden" name="page" value="manage-customers">

    <input type="text" name="search" placeholder="Filter by Customer ID or Name" 
           value="<?php echo htmlspecialchars($search); ?>">

    <button type="submit">Apply</button>
    <button type="button" onclick="window.location.href='main.php?page=manage-customers'">Clear</button>
  </form>
</div>


<section class="content-area">
  <table>
    <thead>
      <tr>
        <th>Customer ID</th>
        <th>Name and Surname</th>
        <th>Email</th>
        <th>Phone</th>
        <th>Address</th>
        <th>Insurance</th>
      </tr>
    </thead>
    <tbody>
      <?php if ($result && $result->num_rows > 0): ?>
        <?php while ($row = $result->fetch_assoc()): ?>
          <tr>
          <form method="post">
            <td>
              <?php echo htmlspecialchars($row['cid']); ?>
              <input type="hidden" name="cid" value="<?php echo $row['cid']; ?>">
            </td>
            <td><input type="text" name="name" value="<?php echo htmlspecialchars($row['name']); ?>"></td>
            <td><input type="text" name="email" value="<?php echo htmlspecialchars($row['email']); ?>"></td>
            <td><input type="text" name="phone" value="<?php echo htmlspecialchars($row['phone']); ?>"></td>
            <td><input type="text" name="address" value="<?php echo htmlspecialchars($row['address']); ?>"></td>
            <td>
              <select name="insurance">
                <option value="verified" <?php if($row['insurance']=="verified") echo "selected"; ?>>Verified</option>
                <option value="unverified" <?php if($row['insurance']=="unverified") echo "selected"; ?>>Unverified</option>
                <option value="pending" <?php if($row['insurance']=="pending") echo "selected"; ?>>Pending</option>
              </select>
            </td>
            <td><button type="submit" name="save">Save</button></td>
          </form>
          </tr>
        <?php endwhile; ?>
      <?php else: ?>
        <tr><td colspan="7">No customers found</td></tr>
      <?php endif; ?>
    </tbody>
  </table>

  <div class="pagination">
    <?php for ($i = 1; $i <= $total_pages; $i++): ?>
      <a href="main.php?page=manage-customers&p=<?php echo $i; ?>&limit=<?php echo $limit; ?>&search=<?php echo urlencode($search); ?>" 
         <?php if ($i == $page) echo 'style="font-weight:bold;"'; ?>>
        <?php echo $i; ?>
      </a>
    <?php endfor; ?>
  </div>
</section>

<?php 
$stmt->close();
$conn->close();
?>
