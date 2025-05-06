<?php
header("Access-Control-Allow-Origin: http://localhost:3000"); // Permite todas as origens
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json');

// Trata requisição preflight (OPTIONS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// A partir daqui, só lida com POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405); // Método não permitido
    echo json_encode(["success" => false, "message" => "Método não permitido."]);
    exit();
}

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
