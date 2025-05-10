<?php
$player = $_POST["username"];

$python = "python";
$script = "/scripts/triggers.py";

$command = escapeshellcmd("$python $script get_score $player");

$output = shell_exec($command);

// Se o Python imprimiu um JSON válido (como no get_score), devolve diretamente
header('Content-Type: application/json');
// Garante que a resposta seja válida e não vazia
if ($output === null || trim($output) === "") {
    echo json_encode(["error" => "Sem resposta do script Python"]);
} else {
    echo $output;
}
