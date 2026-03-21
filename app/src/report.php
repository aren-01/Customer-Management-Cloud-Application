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
  <form id="reportForm">
    <h5>Type Appointment ID</h5>
    <input type="text" name="aid" id="aid" style="width: 115px">
    <button type="submit" style="margin-top: 10px; padding: 6px 10px;">Create Report</button>
  </form>
</section>

<script>
document.getElementById('reportForm').addEventListener('submit', function(e) {
  e.preventDefault();

  const aid = document.getElementById('aid').value.trim();
  if (aid === "") {
    alert("Please enter an Appointment ID");
    return;
  }

  const form = document.createElement('form');
  form.method = 'POST';
  form.action = 'generate-report.php';

  const input = document.createElement('input');
  input.type = 'hidden';
  input.name = 'aid';
  input.value = aid;

  form.appendChild(input);
  document.body.appendChild(form);
  form.submit();
});

</script>
