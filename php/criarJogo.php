<?php
header('Content-Type: application/json');
$conn = new mysqli('localhost', 'root', '', 'pisid_bd9');

$data = json_decode(file_get_contents("php://input"), true);
$nickJogador = $data['nickJogador'] ?? '';
$email = $data['email'] ?? '';

try {
    $stmt = $conn->prepare("CALL criar_jogo(?, ?)");
    $stmt->bind_param("ss", $nickJogador, $email);
    $stmt->execute();

    $result = $stmt->get_result();
    $msg = $result->fetch_assoc();

    echo json_encode(["success" => true, "message" => $msg['Mensagem'] ?? '']);
} catch (mysqli_sql_exception $e) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}

$stmt->close();
$conn->close();
?>
