<?php
$player = $_POST["player"];

$python = "python";
$script = "/scripts/triggers.py";

$command = escapeshellcmd("$python $script close_all_doors $player");

$output = shell_exec($command);

echo json_encode(["output" => $output]);
