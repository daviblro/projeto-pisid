<?php
header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

// Lê os dados JSON da requisição
$data = json_decode(file_get_contents("php://input"), true);

// Extrai o ID do jogo do corpo da requisição
$idJogo = $data['idJogo'] ?? null;
$email = $data['email'] ?? '';
$password = $data['password'] ?? '';

// Valida os parâmetros
if (!$email || !$password || !$idJogo) {
	http_response_code(400);
	echo json_encode(["success" => false, "message" => "Parâmetros incompletos."]);
	exit;
}

// Conecta ao banco de dados usando as credenciais do utilizador
$conn = new mysqli('localhost', $email, $password, 'pisid_bd9');
if ($conn->connect_error) {
	http_response_code(401);
	echo json_encode(["success" => false, "message" => "Erro de autenticação: " . $conn->connect_error]);
	exit;
}

try {
	// Chama a stored procedure para iniciar o jogo
	$stmt = $conn->prepare("CALL iniciar_jogo(?)");
	$stmt->bind_param("i", $idJogo);  // Usando "i" para inteiro (idJogo)
	$stmt->execute();

	// Se o jogo foi iniciado com sucesso
	echo json_encode(["success" => true, "message" => "Jogo iniciado com sucesso!"]);
	$stmt->close();
} catch (mysqli_sql_exception $e) {
	http_response_code(400);
	echo json_encode(["success" => false, "message" => "Erro ao iniciar jogo: " . $e->getMessage()]);
}

$conn->close();
