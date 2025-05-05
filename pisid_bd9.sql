-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: May 06, 2025 at 01:39 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `pisid_bd9`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `alterar_jogo` (IN `p_idjogo` INT, IN `p_NickJogador` VARCHAR(50), IN `p_IDUtilizador` INT)   BEGIN
    -- Verifica se o jogo existe, não está em execução e se o utilizador é o dono do jogo
    IF EXISTS (
        SELECT 1 FROM jogo
        WHERE IDJogo = p_idjogo
        AND Estado != 'jogando'
        AND IDUtilizador = p_IDUtilizador
    ) THEN
        -- Atualiza o jogo com o novo NickJogador
        UPDATE jogo
        SET NickJogador = p_NickJogador
        WHERE IDJogo = p_idjogo;
    ELSE
        -- Se o utilizador não for o dono do jogo, envia uma mensagem de erro com detalhes
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Você não tem permissão para alterar este jogo.';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `alterar_utilizador` (IN `p_email` VARCHAR(50), IN `p_Telemovel` VARCHAR(12), IN `p_Tipo` ENUM('admin','jogador','software'), IN `p_Grupo` INT, IN `p_Nome` VARCHAR(100), IN `p_IDUtilizador` INT, IN `p_Senha` VARCHAR(100))   BEGIN
    DECLARE v_email_antigo VARCHAR(50);
    DECLARE sql_query VARCHAR(1000); -- Variável para armazenar a consulta dinâmica

    -- Obter o email antigo do utilizador antes de alterá-lo
    SELECT Email INTO v_email_antigo
    FROM utilizador
    WHERE IDUtilizador = p_IDUtilizador;

    -- Atualizar a tabela 'utilizador' com os novos dados
    UPDATE utilizador
    SET Telemovel = p_Telemovel,
        Tipo = p_Tipo,
        Grupo = p_Grupo,
        Nome = p_Nome,
        Email = p_email
    WHERE IDUtilizador = p_IDUtilizador;

    -- Se a senha foi fornecida, alterá-la
    IF p_Senha IS NOT NULL AND p_Senha != '' THEN
        -- Preparar a consulta para alterar a senha do utilizador
        SET sql_query = CONCAT('ALTER USER ''', v_email_antigo, ''' IDENTIFIED BY ''', p_Senha, ''';');
        -- Executar a consulta dinâmica
        PREPARE stmt FROM sql_query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    -- Se o email foi fornecido e é diferente do anterior, renomear o usuário
    IF p_email IS NOT NULL AND p_email != '' AND p_email != v_email_antigo THEN
        -- Preparar a consulta para renomear o usuário
        SET sql_query = CONCAT('RENAME USER ''', v_email_antigo, ''' TO ''', p_email, ';');
        -- Executar a consulta dinâmica
        PREPARE stmt FROM sql_query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `criar_jogo` (IN `p_nick_jogador` VARCHAR(50), IN `p_email_utilizador` VARCHAR(100))   BEGIN
    DECLARE v_max_sound INT DEFAULT 100;
    DECLARE v_id_utilizador INT;

    -- Tenta obter o ID do utilizador
    SELECT IDUtilizador INTO v_id_utilizador
    FROM utilizador
    WHERE Email = p_email_utilizador;

    -- Se não encontrou nenhum ID, dá erro (mas tratamos o erro com CONTINUE HANDLER)
    IF v_id_utilizador IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utilizador não encontrado com o email do utilizador atual.';
    ELSE
        -- Inserir o novo jogo
        INSERT INTO jogo (
            NickJogador,
            DataHoraInicio,
            Estado,
            IDUtilizador,
            max_sound
        )
        VALUES (
            p_nick_jogador,
            CURRENT_TIMESTAMP,
            'nao_inicializado',
            v_id_utilizador,
            v_max_sound
        );

        -- Mensagem de sucesso
        SELECT 'Jogo criado com sucesso!' AS Mensagem;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `criar_utilizador` (IN `p_email` VARCHAR(50), IN `p_nome` VARCHAR(100), IN `p_telemovel` VARCHAR(12), IN `p_tipo` ENUM('admin','jogador','software'), IN `p_grupo` INT, IN `p_password` VARCHAR(100))   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Em caso de erro, desfaz qualquer mudança (opcional: ROLLBACK)
        SELECT 'Erro ao criar utilizador.' AS MensagemErro;
    END;

    -- 1. Verifica se o utilizador já existe
    IF NOT EXISTS (SELECT 1 FROM utilizador WHERE Email = p_email) THEN

        -- 2. Insere na tabela
        INSERT INTO utilizador (Email, Nome, Telemovel, Tipo, Grupo)
        VALUES (p_email, p_nome, p_telemovel, p_tipo, p_grupo);

        -- 3. Cria o utilizador MySQL
        SET @sql_create = CONCAT(
            'CREATE USER ''', p_email, '''@''localhost'' IDENTIFIED BY ''', p_password, ''';'
        );
        PREPARE stmt1 FROM @sql_create;
        EXECUTE stmt1;
        DEALLOCATE PREPARE stmt1;

        -- 4. Concede a role (pré-criada) ao utilizador
        SET @sql_grant = CONCAT(
            'GRANT ', p_tipo, ' TO ''', p_email, '''@''localhost'' WITH ADMIN OPTION;'
        );
        PREPARE stmt2 FROM @sql_grant;
        EXECUTE stmt2;
        DEALLOCATE PREPARE stmt2;

        -- 5. Mensagem de sucesso
        SELECT 'Utilizador criado com sucesso!' AS Mensagem;

    ELSE
        SELECT 'Utilizador já existe.' AS Mensagem;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `remover_utilizador` (IN `p_IDUtilizador` INT(50))   BEGIN
    DECLARE v_email VARCHAR(100);

    -- 1. Verifica se o utilizador existe e obtém o email
    SELECT Email INTO v_email
    FROM utilizador
    WHERE IDUtilizador = p_IDUtilizador;

    -- 2. Se encontrou o email, continua
    IF v_email IS NOT NULL THEN
        -- 3. Remove da tabela pisid.utilizador
        DELETE FROM utilizador WHERE IDUtilizador = p_IDUtilizador;

        -- 4. Remove o utilizador do MySQL
        SET @sql_drop = CONCAT(
            'DROP USER IF EXISTS ''', v_email, '''@''localhost'''
        );
        PREPARE stmt1 FROM @sql_drop;
        EXECUTE stmt1;
        DEALLOCATE PREPARE stmt1;
    END IF;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `jogo`
--

CREATE TABLE `jogo` (
  `IDJogo` int(11) NOT NULL,
  `NickJogador` varchar(50) DEFAULT NULL,
  `DataHoraInicio` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `DataHoraFim` timestamp NULL DEFAULT NULL,
  `Estado` enum('nao_inicializado','jogando','finalizado') DEFAULT NULL,
  `max_sound` int(11) NOT NULL,
  `IDUtilizador` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `jogo`
--

INSERT INTO `jogo` (`IDJogo`, `NickJogador`, `DataHoraInicio`, `DataHoraFim`, `Estado`, `max_sound`, `IDUtilizador`) VALUES
(30, 'Mufasa', '2025-05-05 23:31:51', NULL, 'nao_inicializado', 100, 13);

--
-- Triggers `jogo`
--
DELIMITER $$
CREATE TRIGGER `criar_salas_apos_criar_jogo` AFTER INSERT ON `jogo` FOR EACH ROW BEGIN
  DECLARE i INT DEFAULT 0;
  DECLARE nova_IDSala INT;

  -- Criar 11 salas (de 0 a 10) para o novo jogo
  WHILE i <= 10 DO
    -- Gerar um novo IDSala único (ID da sala será calculado)
    SET nova_IDSala = (NEW.IDJogo * 100) + i;

    -- Inserir nova sala com valores específicos
    INSERT INTO sala (
      IDJogo_Sala, IDSala,
      NumeroMarsamisOdd, NumeroMarsamisEven,
      Pontos, Gatilhos
    )
    VALUES (
      NEW.IDJogo,
      nova_IDSala,
      IF(i = 0, 15, 0),  -- 15 MarsamisOdd na sala 0
      IF(i = 0, 15, 0),  -- 15 MarsamisEven na sala 0
      0, 0
    );
    
    SET i = i + 1;
  END WHILE;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `mensagens`
--

CREATE TABLE `mensagens` (
  `IDMensagem` int(11) NOT NULL,
  `Hora` timestamp NULL DEFAULT NULL,
  `Sensor` int(11) DEFAULT NULL,
  `Leitura` decimal(10,2) DEFAULT NULL,
  `TipoAlerta` varchar(50) DEFAULT NULL,
  `Msg` varchar(100) DEFAULT NULL,
  `IDJogo` int(11) NOT NULL,
  `HoraEscrita` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `movement`
--

CREATE TABLE `movement` (
  `IDMovement` int(11) NOT NULL,
  `Marsami` varchar(50) DEFAULT NULL,
  `RoomOrigin` varchar(50) DEFAULT NULL,
  `RoomDestiny` varchar(50) DEFAULT NULL,
  `Status` varchar(50) DEFAULT NULL,
  `IDJogo` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sala`
--

CREATE TABLE `sala` (
  `IDJogo_Sala` int(11) NOT NULL,
  `IDSala` int(11) NOT NULL,
  `NumeroMarsamisOdd` int(11) DEFAULT NULL,
  `NumeroMarsamisEven` int(11) DEFAULT NULL,
  `Pontos` int(11) DEFAULT NULL,
  `Gatilhos` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `sala`
--

INSERT INTO `sala` (`IDJogo_Sala`, `IDSala`, `NumeroMarsamisOdd`, `NumeroMarsamisEven`, `Pontos`, `Gatilhos`) VALUES
(30, 3000, 15, 15, 0, 0),
(30, 3001, 0, 0, 0, 0),
(30, 3002, 0, 0, 0, 0),
(30, 3003, 0, 0, 0, 0),
(30, 3004, 0, 0, 0, 0),
(30, 3005, 0, 0, 0, 0),
(30, 3006, 0, 0, 0, 0),
(30, 3007, 0, 0, 0, 0),
(30, 3008, 0, 0, 0, 0),
(30, 3009, 0, 0, 0, 0),
(30, 3010, 0, 0, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `sound`
--

CREATE TABLE `sound` (
  `IDSound` int(11) NOT NULL,
  `Hour` datetime DEFAULT NULL,
  `Sound` float DEFAULT NULL,
  `IDJogo` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `utilizador`
--

CREATE TABLE `utilizador` (
  `Telemovel` varchar(12) DEFAULT NULL,
  `Tipo` enum('admin','jogador','software') NOT NULL,
  `Grupo` int(11) DEFAULT NULL,
  `Nome` varchar(100) DEFAULT NULL,
  `IDUtilizador` int(11) NOT NULL,
  `Email` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `utilizador`
--

INSERT INTO `utilizador` (`Telemovel`, `Tipo`, `Grupo`, `Nome`, `IDUtilizador`, `Email`) VALUES
('111222333', 'jogador', 9, 'teste', 13, 'teste@gmail.com');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `jogo`
--
ALTER TABLE `jogo`
  ADD PRIMARY KEY (`IDJogo`),
  ADD KEY `IDUtilizador_Jogo` (`IDUtilizador`) USING BTREE;

--
-- Indexes for table `mensagens`
--
ALTER TABLE `mensagens`
  ADD PRIMARY KEY (`IDMensagem`) USING BTREE,
  ADD KEY `IDJogo_Mensagens` (`IDJogo`) USING BTREE;

--
-- Indexes for table `movement`
--
ALTER TABLE `movement`
  ADD PRIMARY KEY (`IDMovement`),
  ADD KEY `IDJogo_Movement` (`IDJogo`) USING BTREE;

--
-- Indexes for table `sala`
--
ALTER TABLE `sala`
  ADD PRIMARY KEY (`IDSala`) USING BTREE,
  ADD KEY `IDJogo_Sala` (`IDJogo_Sala`) USING BTREE;

--
-- Indexes for table `sound`
--
ALTER TABLE `sound`
  ADD PRIMARY KEY (`IDSound`),
  ADD KEY `IDJogo_Sound` (`IDJogo`) USING BTREE;

--
-- Indexes for table `utilizador`
--
ALTER TABLE `utilizador`
  ADD PRIMARY KEY (`IDUtilizador`),
  ADD UNIQUE KEY `Email` (`Email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `jogo`
--
ALTER TABLE `jogo`
  MODIFY `IDJogo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT for table `mensagens`
--
ALTER TABLE `mensagens`
  MODIFY `IDMensagem` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `movement`
--
ALTER TABLE `movement`
  MODIFY `IDMovement` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sound`
--
ALTER TABLE `sound`
  MODIFY `IDSound` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `utilizador`
--
ALTER TABLE `utilizador`
  MODIFY `IDUtilizador` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `jogo`
--
ALTER TABLE `jogo`
  ADD CONSTRAINT `IDUtilizador_Jogo` FOREIGN KEY (`IDUtilizador`) REFERENCES `utilizador` (`IDUtilizador`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `mensagens`
--
ALTER TABLE `mensagens`
  ADD CONSTRAINT `IDJogo_Mensagens` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `movement`
--
ALTER TABLE `movement`
  ADD CONSTRAINT `IDJogo_Movement` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `sala`
--
ALTER TABLE `sala`
  ADD CONSTRAINT `IDJogo_Sala` FOREIGN KEY (`IDJogo_Sala`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `sound`
--
ALTER TABLE `sound`
  ADD CONSTRAINT `IDJogo_Sound` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
