<?php
ob_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Admin Panel</title>
  <link
    rel="stylesheet"
    href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"
    integrity="sha512-p6O/Ic3Y8Vb66KYf2meJtKjhmZo6SPLD+Pv/OFZLObpYWdPzcU+1H7tJDKI9UqK/n+k3b6+1G539T3h2yYBiFw=="
    crossorigin="anonymous"
    referrerpolicy="no-referrer"
  />
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <aside class="sidebar">
    <div class="logo">Admin Panel</div>
    <nav>
      <ul>
        <?php
          $page = $_GET['page'] ?? 'home';

          function isActive($name, $page) {
            return $name === $page ? 'class="active"' : '';
          }
        ?>
        <li><a href="main.php" <?= $page === 'home' ? 'class="active"' : '' ?>><i class="fas fa-home"></i>Main Page</a></li>
        <li><a href="?page=manage-customers" <?= isActive('manage-customers', $page) ?>><i class="fas fa-users"></i> Manage Customers</a></li>
        <li><a href="?page=add-customer" <?= isActive('add-customer', $page) ?>><i class="fas fa-user-plus"></i> Add Customer</a></li>
        <li><a href="?page=manage-appointments" <?= isActive('manage-appointments', $page) ?>><i class="fas fa-calendar-check"></i> Manage Appointments</a></li>
        <li><a href="?page=schedule" <?= isActive('schedule', $page) ?>><i class="fas fa-clock"></i> Schedule Appointment</a></li>
        <li><a href="?page=verify" <?= isActive('verify', $page) ?>><i class="fas fa-shield-alt"></i> Verify Insurance</a></li>
        <li><a href="?page=report" <?= isActive('report', $page) ?>><i class="fas fa-file-pdf"></i> Create Report</a></li>
        <li><a href="?page=settings" <?= isActive('settings', $page) ?>><i class="fas fa-cog"></i> Settings</a></li>
      </ul>
    </nav>
  </aside>

  <div class="main-content">
    <header class="navbar">
      <div class="icons">
        <i class="fas fa-flag"></i>
        <i class="fas fa-moon"></i>
        <i class="fas fa-bell"></i>
        <i class="fas fa-envelope"></i>
        <i class="fas fa-expand"></i>
        <i class="fas fa-th"></i>
      </div>
      <div class="user">
        <div class="info"></div>
      </div>
    </header>

    <section class="content-area">
      <?php
      
      if (isset($_GET['list']) && $_GET['list'] == '1') {
          include 'manage-customers.php';
          exit;
      }

      $page = $_GET['page'] ?? 'home';
      $allowed_pages = ['manage-appointments', 'manage-customers', 'report', 'schedule', 'settings', 'verify', 'add-customer'];

      if (in_array($page, $allowed_pages)) {
          include("$page.php");
      } else {
          include("introduction.php");
      }
      ?>
    </section>
  </div>
</body>
</html>
<?php

ob_end_flush();
?>
