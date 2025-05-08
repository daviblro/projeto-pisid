<?php
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
