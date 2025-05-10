<?php
$db = "pisid_bd9";
$dbhost = "localhost";
$username = $_POST["username"];
$password = $_POST["password"];

$conn = mysqli_connect($dbhost, $username, $password, $db);

if (!$conn) {
	echo json_encode(["success" => false, "error" => mysqli_connect_error()]);
	exit;
}

$sql = "CALL get_mensagens()";

$response["mensagens"] = array();
$result = mysqli_query($conn, $sql);
if ($result) {
	if (mysqli_num_rows($result) > 0) {
		while ($r = mysqli_fetch_assoc($result)) {
			try {
				$ad = array();
				$ad["Msg"] = $r['Msg'];
				$ad["Leitura"] = $r['Leitura'];
				$ad["TipoAlerta"] = $r['TipoAlerta'];
				$ad["Hora"] = $r['Hora'];
				$ad["HoraEscrita"] = $r['HoraEscrita'];
				array_push($response["mensagens"], $ad);
			} catch (Exception $e) {
				echo ($e);
			}
		}
	}
}
$conn->close();
header('Content-Type: application/json');
// tell browser that its a json data
echo json_encode($response);
//converting array to JSON string
