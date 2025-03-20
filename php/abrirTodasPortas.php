-<?php
    $db = "pisid"; 
	$dbhost = "localhost"; 
	$username = $_POST["username"];
	$password = $_POST["password"];
	$conn = mysqli_connect($dbhost, $username, $password, $db);	
	$sql = "CALL startGame()";
	$result = mysqli_query($conn, $sql);
	mysqli_close ($conn);
	echo json_encode($result);
?>