<?php
$db = "pisid_bd9"; 
$dbhost = "localhost"; 
$username = $_POST["username"];
$password = $_POST["password"];
$sensor = $_POST["sensor"];

$conn = mysqli_connect($dbhost, $username, $password, $db);// Create connection

if (!$conn) {// Check connection
    die("Connection failed: " . mysqli_connect_error());
}

$sql = "SELECT Hour, Sound, normalnoise from sound, setupmaze where IDSound = $sensor AND Hour >= NOW() - INTERVAL 10 SECOND  ORDER BY Hour DESC;";

$result = mysqli_query($conn, $sql);// Execute the query
$response = array();
if (mysqli_num_rows($result) > 0) {// Check if any row is returned
     while ($row = mysqli_fetch_assoc($result)) {//Iterates trough the result and puts entries in response
        array_push($response, $row);
    }
} else {
    $response = array();// If no rows are returned, initialize an empty response
}

mysqli_close($conn);// Close the connection

echo json_encode($response);// Convert the response array to JSON format
?>