<?php
header("Access-Control-Allow-Origin: http://localhost:3000"); // Permite todas as origens
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json');

$host = 'localhost';
$db = 'pisid_bd9';
$user = 'root';
$pass = ''; // ou sua senha do root
$conn = new mysqli($host, $user, $pass, $db);

if ($conn->connect_error) {
    echo json_encode([]);
    exit;
}

$idUtilizador = $_GET['idUtilizador'];

$stmt = $conn->prepare("SELECT IDJogo, NickJogador FROM jogo WHERE IDUtilizador = ?");
$stmt->bind_param("i", $idUtilizador);
$stmt->execute();
$result = $stmt->get_result();

$jogos = [];
while ($row = $result->fetch_assoc()) {
    $jogos[] = $row;
}

echo json_encode($jogos);

$stmt->close();
$conn->close();
