<?php
$db = "pisid_bd9";
$dbhost = "localhost";
$username = $_POST["username"];
$password = $_POST["password"];
$idJogo = $_POST["jogo"];

$conn = mysqli_connect($dbhost, $username, $password, $db); // Create connection

if (!$conn) {
	echo json_encode(["success" => false, "error" => mysqli_connect_error()]);
	exit;
}

$sql = "CALL get_sensores(?)";
$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "i", $idJogo);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);

$response = array();
if ($result && mysqli_num_rows($result) > 0) { // Check if any row is returned
	while ($row = mysqli_fetch_assoc($result)) { //Iterates trough the result and puts entries in response
		array_push($response, $row);
	}
} else {
	$response = array(); // If no rows are returned, initialize an empty response
}

$conn->close();
echo json_encode($response); // Convert the response array to JSON format
