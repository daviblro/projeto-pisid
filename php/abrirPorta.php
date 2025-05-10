<?php
    $player = $_POST["username"]; // ou outro identificador
    $origin = $_POST["SalaOrigemController"];
    $destiny = $_POST["SalaDestinoController"];

    // Caminho completo para o Python e o script
    $python = "python3"; // ou apenas "python" no Windows
    $script = "/scripts/triggers.py";
    
    // Monta comando e escapa os argumentos
    $command = escapeshellcmd("$python $script open_door $player $origin $destiny");

    // Executa
    $output = shell_exec($command);

    // Retorna resposta
    echo json_encode(["output" => $output]);
?>
