<?php
header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

$db = "pisid_bd9";
$dbhost = "localhost";
$username = $_POST["username"]; // Este é o email
$password = $_POST["password"];

$conn = mysqli_connect($dbhost, $username, $password, $db);
if (!$conn) {
	die(json_encode(["success" => false, "error" => "Connection failed"]));
}

// Buscar o IDJogo e IDUtilizador do username logado
$sql = "CALL getIdJogo_IdUtilizador()";

$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "s", $username);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);

$response = array("success" => false);
if ($row = mysqli_fetch_assoc($result)) {
	$response["success"] = true;
	$response["idJogo"] = $row["IDJogo"];
	$response["idUtilizador"] = $row["IDUtilizador"];
}

mysqli_stmt_close($stmt);
mysqli_close($conn);
echo json_encode($response);
