<?php
ob_start(); 
ini_set('display_errors', 0);
error_reporting(0);

require('fpdf/fpdf.php');

$servername = "mysql";
$username = "root";
$password = "aplusfamily";
$dbname = "db_health";

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
  die("Connection failed: " . $conn->connect_error);
}

$aid = trim($_POST['aid'] ?? $_GET['aid'] ?? '');
if ($aid === '') {
  echo "<script>alert('Please enter an appointment ID'); window.history.back();</script>";
  exit;
}

$stmt = $conn->prepare("SELECT * FROM appointments WHERE aid = ?");
$stmt->bind_param("s", $aid);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
  echo "<script>alert('Invalid appointment ID'); window.history.back();</script>";
  exit;
}

$appointment = $result->fetch_assoc();
$cid = $appointment['cid'];
$cust = $conn->query("SELECT * FROM customers WHERE cid = '$cid'")->fetch_assoc();

class PDF extends FPDF {
  function Header() {
    $this->SetFont('Arial','B',16);
    $this->Cell(0,10,'A+ Family Healthcare Appointment Report',0,1,'C');
    $this->Ln(5);
  }
}

$pdf = new PDF();
$pdf->AddPage();
$pdf->SetFont('Arial','B',14);
$pdf->Cell(0,10,'Customer Information',0,1);
$pdf->SetFont('Arial','',12);

$pdf->Cell(0,8,mb_convert_encoding('Name: ' . $cust['name'], 'ISO-8859-1', 'UTF-8'),0,1);
$pdf->Cell(0,8,'Email: ' . $cust['email'],0,1);
$pdf->Cell(0,8,'Phone: ' . $cust['phone'],0,1);
$pdf->Cell(0,8,mb_convert_encoding('Address: ' . $cust['address'], 'ISO-8859-1', 'UTF-8'),0,1);
$pdf->Cell(0,8,'Insurance: ' . ucfirst($cust['insurance']),0,1);
$pdf->Ln(6);

$pdf->SetFont('Arial','B',14);
$pdf->Cell(0,10,'Appointment Information',0,1);
$pdf->SetFont('Arial','',12);
$pdf->Cell(0,8,'Appointment ID: ' . $appointment['aid'],0,1);
$pdf->Cell(0,8,'Date: ' . $appointment['date'],0,1);
$pdf->Cell(0,8,'Status: ' . ucfirst($appointment['status']),0,1);
$pdf->Cell(0,8,'Payment: ' . ucfirst($appointment['payment']),0,1);

$filename = "Appointment_Report_AID_{$aid}.pdf";
ob_end_clean(); 
$pdf->Output('D', $filename);
exit;
?>
