<?php
$dbname = "pisid_bd9";
$dbhost = "localhost";

// Utilizador interno para SELECT (não o que faz login)
$internalUser = "root";
$internalPass = ""; // ajuste conforme sua senha

header('Content-Type: application/json');

$response = [
    "success" => false,
    "message" => ""
];

// Verifica se os dados foram enviados
if (!isset($_POST['username']) || !isset($_POST['password'])) {
    $response["message"] = "Campos de login ausentes.";
    echo json_encode($response);
    exit;
}

$username = $_POST['username'];
$password = $_POST['password'];

// 1. Tenta conectar com as credenciais fornecidas
$conn = @mysqli_connect($dbhost, $username, $password, $dbname);

if ($conn) {
    mysqli_close($conn); // Login funcionou, fecha essa conexão

    // 2. Conecta com o utilizador interno para buscar dados adicionais
    $internalConn = @mysqli_connect($dbhost, $internalUser, $internalPass, $dbname);
    
    if (!$internalConn) {
        $response["message"] = "Erro interno ao obter dados do utilizador.";
        echo json_encode($response);
        exit;
    }

    // 3. Busca dados na tabela utilizador
    $stmt = $internalConn->prepare("SELECT IDUtilizador, Nome FROM utilizador WHERE Email = ?");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    $userData = $result->fetch_assoc();

    if ($userData) {
        $response["success"] = true;
        $response["message"] = "Login bem-sucedido.";
        $response["user"] = [
            "id" => $userData["IDUtilizador"],
            "nome" => $userData["Nome"],
            "email" => $username
        ];
    } else {
        $response["message"] = "Utilizador não encontrado na tabela.";
    }

    $stmt->close();
    $internalConn->close();
} else {
    $response["message"] = "Login falhou. Verifique email e senha.";
}

echo json_encode($response);
?>
