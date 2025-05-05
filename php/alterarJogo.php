<?php
header('Content-Type: application/json');
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
