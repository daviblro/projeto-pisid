-<?php
    $db = "pisid"; 
	$dbhost = "localhost"; 
	$username = $_POST["username"];
	$password = $_POST["password"];
	$doorOrigin = $_POST["SalaOrigemController"];
	$doorDestiny = $_POST["SalaDestinoController"];
	$conn = mysqli_connect($dbhost, $username, $password, $db);	
	$sql = "CALL closeDoor($doorOrigin,$doorDestiny)";
	$result = mysqli_query($conn, $sql);
	mysqli_close ($conn);
	echo json_encode($result);
?>