<?php
header("Access-Control-Allow-Origin: http://localhost:3000"); // Permite todas as origens
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json');
$conn = new mysqli('localhost', 'root', '', 'pisid_bd9');

if ($conn->connect_error || !isset($_GET['idJogo'])) {
    echo json_encode(null);
    exit;
}

$idJogo = intval($_GET['idJogo']);
$stmt = $conn->prepare("SELECT NickJogador FROM jogo WHERE IDJogo = ?");
$stmt->bind_param("i", $idJogo);
$stmt->execute();
$result = $stmt->get_result();
echo json_encode($result->fetch_assoc());
$stmt->close();
$conn->close();
?>
