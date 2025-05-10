<?php
$player = $_POST["username"];

$python = "python";
$script = "/scripts/triggers.py";

$command = escapeshellcmd("$python $script open_all_doors $player");

$output = shell_exec($command);

echo json_encode(["output" => $output]);
