<?php
$servername = "mysql";
$username   = "root"; 
$password   = "aplusfamily"; 
$dbname     = "db_health";

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}


if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST['save_appointment'])) {
    $aid     = $_POST['aid'];
    $cid     = $_POST['cid'];
    $date    = $_POST['date'];
    $status  = $_POST['status'];
    $payment = $_POST['payment'];

    if (!empty($aid)) {
        $stmt3 = $conn->prepare("UPDATE appointments SET cid=?, date=?, status=?, payment=? WHERE aid=?");
        $stmt3->bind_param("isssi", $cid, $date, $status, $payment, $aid);
        $stmt3->execute();
        $stmt3->close();
    }
}

$search = "";
$filter_type = isset($_GET['filter_type']) ? $_GET['filter_type'] : "aid"; 
$search_sql = "";

if (isset($_GET['search']) && trim($_GET['search']) !== "") {
    $search = trim($_GET['search']);
    if ($filter_type == "cid" && ctype_digit($search)) {
        $search_sql = "WHERE cid = " . (int)$search;
    } elseif ($filter_type == "aid" && ctype_digit($search)) {
        $search_sql = "WHERE aid = " . (int)$search;
    }
}

$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 20; 
if ($limit < 1) $limit = 10;

$page = isset($_GET['p']) ? (int)$_GET['p'] : 1;
if ($page < 1) $page = 1; 

$total_sql = "SELECT COUNT(*) AS total FROM appointments " . ($search_sql ? $search_sql : "");
$total_result = $conn->query($total_sql);
$total_row    = $total_result->fetch_assoc();
$total_records= (int)$total_row['total'];
$total_pages  = max(1, (int)ceil($total_records / $limit));

if ($page > $total_pages) $page = $total_pages; 
$offset = ($page - 1) * $limit;


$sql = "SELECT aid, cid, date, status, payment 
        FROM appointments 
        " . ($search_sql ? $search_sql : "") . " 
        ORDER BY aid ASC 
        LIMIT ? OFFSET ?";

$stmt = $conn->prepare($sql);
$stmt->bind_param("ii", $limit, $offset);
$stmt->execute();
$result = $stmt->get_result();



if (isset($_GET['api']) && $_GET['api'] == '1') {
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

<h5>Manage Appointments</h5>

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
button {
  padding: 6px 12px;
  cursor: pointer;
}
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
.search-form button,
.search-form .clear-btn {
  padding: 6px 10px;
}
.radio-group {
  display: flex;
  align-items: center;
  gap: 15px;
  margin-left: 10px;
}
.radio-group label {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 14px;
  white-space: nowrap;
}
</style>

<div class="search-bar">
  <form method="get" action="main.php" class="search-form">
    <input type="hidden" name="page" value="manage-appointments">

    <input type="text" name="search" placeholder="Filter by Appointment ID or Customer ID" 
           value="<?php echo htmlspecialchars($search); ?>">

    <button type="submit">Apply</button>
    <button type="button" onclick="window.location.href='main.php?page=manage-appointments'">Clear</button>

    <span class="radio-group">
      <label><input type="radio" name="filter_type" value="aid" <?php if($filter_type=="aid") echo "checked"; ?>> Appointment ID</label>
      <label><input type="radio" name="filter_type" value="cid" <?php if($filter_type=="cid") echo "checked"; ?>> Customer ID</label>
    </span>
  </form>
</div>

<section class="content-area">
<table>
  <thead>
    <tr>
      <th>Appointment ID</th>
      <th>Customer ID</th>
      <th>Appointment Date</th>
      <th>Appointment Status</th>
      <th>Payment</th>
    </tr>
  </thead>
  <tbody>
    <?php if ($result && $result->num_rows > 0): ?>
        <?php while ($row = $result->fetch_assoc()): ?>
        <tr>
          <form method="post">
            <td>
              <?php echo htmlspecialchars($row['aid']); ?>
              <input type="hidden" name="aid" value="<?php echo $row['aid']; ?>">
            </td>
            <td><input type="number" name="cid" value="<?php echo htmlspecialchars($row['cid']); ?>"></td>
            <td><input type="date" name="date" value="<?php echo htmlspecialchars($row['date']); ?>"></td>
            <td>
              <select name="status">
                <option value="upcoming"    <?php if($row['status']=="upcoming") echo "selected"; ?>>Upcoming</option>
                <option value="successful"  <?php if($row['status']=="successful") echo "selected"; ?>>Successful</option>
                <option value="unsuccessful"<?php if($row['status']=="unsuccessful") echo "selected"; ?>>Unsuccessful</option>
                <option value="canceled"    <?php if($row['status']=="canceled") echo "selected"; ?>>Canceled</option>
              </select>
            </td>
            <td>
              <select name="payment">
                <option value="successful"   <?php if($row['payment']=="successful") echo "selected"; ?>>Successful</option>
                <option value="unsuccessful" <?php if($row['payment']=="unsuccessful") echo "selected"; ?>>Unsuccessful</option>
              </select>
            </td>
            <td><button type="submit" name="save_appointment">Save</button></td>
          </form>
        </tr>
        <?php endwhile; ?>
    <?php else: ?>
        <tr><td colspan="6">No appointments found</td></tr>
    <?php endif; ?>
  </tbody>
</table>

<div class="pagination">
  <?php for ($i = 1; $i <= $total_pages; $i++): ?>
    <a href="main.php?page=manage-appointments&p=<?php echo $i; ?>&limit=<?php echo $limit; ?>&search=<?php echo urlencode($search); ?>&filter_type=<?php echo $filter_type; ?>" 
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
