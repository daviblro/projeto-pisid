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

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT); // Habilita exceções

$conn = new mysqli('localhost', 'root', '', 'pisid_bd9');

$data = json_decode(file_get_contents("php://input"), true);
$idJogo = $data['idJogo'];
$nickJogador = $data['nickJogador'];
$idUtilizador = $data['idUtilizador'];

$response = [];

try {
    $stmt = $conn->prepare("CALL alterar_jogo(?, ?, ?)");
    $stmt->bind_param("isi", $idJogo, $nickJogador, $idUtilizador);
    $stmt->execute();
    $response["success"] = true;
    $response["message"] = "Jogo alterado com sucesso!";
} catch (mysqli_sql_exception $e) {
    http_response_code(400);
    $response["success"] = false;
    $response["message"] = "Erro ao alterar jogo: " . $e->getMessage();
}

echo json_encode($response);

$stmt->close();
$conn->close();
?>
