<?php
$db = "pisid_bd9";
$dbhost = "localhost";

$username = $_POST["username"];
$password = $_POST["password"];

$conn = mysqli_connect($dbhost, $username, $password, $db);
if (!$conn) {
    die(json_encode(["success" => false, "error" => "Connection failed"]));
}

// Busca o ID do jogo mais recente (você pode mudar para o jogo ativo, ou outro critério)
$sql = "SELECT IDJogo FROM jogo ORDER BY IDJogo DESC LIMIT 1";
$result = mysqli_query($conn, $sql);
$response = array("success" => false);

if ($row = mysqli_fetch_assoc($result)) {
    $response["success"] = true;
    $response["idJogo"] = $row["IDJogo"];
}

mysqli_close($conn);
echo json_encode($response);
?>
