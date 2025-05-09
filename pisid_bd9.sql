-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Tempo de geração: 09-Maio-2025 às 18:23
-- Versão do servidor: 10.4.32-MariaDB
-- versão do PHP: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Banco de dados: `pisid_bd9`
--

DELIMITER $$
--
-- Procedimentos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `alterar_jogo` (IN `p_idjogo` INT, IN `p_NickJogador` VARCHAR(50))   BEGIN
    DECLARE v_id_utilizador INT;
    DECLARE v_email VARCHAR(50);

    SET v_email = SUBSTRING_INDEX(USER(), '@', 2);

    SELECT IDUtilizador INTO v_id_utilizador
    FROM utilizador
    WHERE Email = v_email;

    IF EXISTS (
        SELECT 1 FROM jogo
        WHERE IDJogo = p_idjogo
        AND Estado != 'jogando'
        AND IDUtilizador = v_id_utilizador
    ) THEN
        UPDATE jogo
        SET NickJogador = p_NickJogador
        WHERE IDJogo = p_idjogo;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Você não tem permissão para alterar este jogo.';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `alterar_utilizador` (IN `p_emailAntigo` VARCHAR(50), IN `p_emailNovo` VARCHAR(50), IN `p_NomeNovo` VARCHAR(100), IN `p_TelemovelNovo` VARCHAR(12), IN `p_GrupoNovo` INT, IN `p_SenhaNovaOpcional` VARCHAR(100))   BEGIN
    DECLARE v_email_antigo VARCHAR(50);
    DECLARE v_IDUtilizador INT;
    DECLARE sql_query VARCHAR(1000);

    SET v_email_antigo = p_emailAntigo;

    SELECT IDUtilizador INTO v_IDUtilizador
    FROM utilizador
    WHERE Email = v_email_antigo;

    IF p_emailNovo IS NOT NULL AND p_emailNovo != '' AND TRIM(p_emailNovo) != TRIM(v_email_antigo) THEN
        -- Atualiza dados e email
        UPDATE utilizador
        SET Telemovel = p_TelemovelNovo,
            Grupo = p_GrupoNovo,
            Nome = p_NomeNovo,
            Email = p_emailNovo
        WHERE IDUtilizador = v_IDUtilizador;

        -- Renomeia o utilizador do sistema
        SET sql_query = CONCAT('RENAME USER ''', v_email_antigo, '''@''localhost'' TO ''', p_emailNovo, '''@''localhost'';');
        PREPARE stmt FROM sql_query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        -- Atualiza email antigo para o novo
        SET v_email_antigo = p_emailNovo;
    ELSE
        -- Só atualiza os restantes dados (sem mexer no email)
        UPDATE utilizador
        SET Telemovel = p_TelemovelNovo,
            Grupo = p_GrupoNovo,
            Nome = p_NomeNovo
        WHERE IDUtilizador = v_IDUtilizador;
    END IF;

    -- Se a senha foi passada, altera também
    IF p_SenhaNovaOpcional IS NOT NULL AND p_SenhaNovaOpcional != '' THEN
        SET sql_query = CONCAT('ALTER USER ''', v_email_antigo, '''@''localhost'' IDENTIFIED BY ''', p_SenhaNovaOpcional, ''';');
        PREPARE stmt FROM sql_query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `criar_jogo` (IN `p_nick_jogador` VARCHAR(50))   BEGIN
    DECLARE v_id_utilizador INT;
    DECLARE v_email VARCHAR(50);

	SET v_email = SUBSTRING_INDEX(USER(), '@', 2);
    
    -- Tenta obter o ID do utilizador
    SELECT IDUtilizador INTO v_id_utilizador
    FROM utilizador
    WHERE Email = v_email;
        
    -- Se não encontrou nenhum ID, dá erro (mas tratamos o erro com CONTINUE HANDLER)
    IF v_id_utilizador IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utilizador não encontrado com o email do utilizador atual.';
    ELSE
        -- Inserir o novo jogo
        INSERT INTO jogo (
            NickJogador,
            Estado,
            IDUtilizador
        )
        VALUES (
            p_nick_jogador,
            'nao_inicializado',
            v_id_utilizador
        );

        -- Mensagem de sucesso
        SELECT 'Jogo criado com sucesso!' AS Mensagem;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `criar_utilizador` (IN `p_email` VARCHAR(50), IN `p_nome` VARCHAR(100), IN `p_telemovel` VARCHAR(12), IN `p_tipo` VARCHAR(20), IN `p_grupo` INT, IN `p_password` VARCHAR(100))   BEGIN
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
	SET @sql_grant = CONCAT('GRANT ', p_tipo, ' TO ''', p_email, '''@''localhost'';');
        PREPARE stmt2 FROM @sql_grant;
        EXECUTE stmt2;
        DEALLOCATE PREPARE stmt2;

	-- 4.1 Define como role padrão
	SET @sql_default = CONCAT('SET DEFAULT ROLE ', p_tipo, ' TO ''', p_email, '''@''localhost'';');
	PREPARE stmt3 FROM @sql_default;
	EXECUTE stmt3;
	DEALLOCATE PREPARE stmt3;

        -- 5. Mensagem de sucesso
        SELECT 'Utilizador criado com sucesso!' AS Mensagem;

    ELSE
        SELECT 'Utilizador já existe.' AS Mensagem;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getIdJogo_IdUtilizador` ()   BEGIN
	DECLARE v_id_utilizador INT;
    DECLARE v_email VARCHAR(50);

    -- Extrai o email do utilizador atual (até o '@')
    SET v_email = SUBSTRING_INDEX(USER(), '@', 2);

    -- Tenta obter o ID do utilizador
    SELECT IDUtilizador INTO v_id_utilizador
    FROM utilizador
    WHERE Email = v_email;

    -- Retorna o ID do jogo mais recente criado por esse utilizador
    SELECT IDJogo, v_id_utilizador AS IDUtilizador
    FROM jogo
    WHERE IDUtilizador = v_id_utilizador
    ORDER BY IDJogo DESC
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_marsami_room` ()   BEGIN
	SELECT * 
    FROM sala 
    WHERE IDJogo_Sala = (SELECT MAX(IDJogo_Sala) FROM sala)
    ORDER BY IDSala;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_mensagens` ()   BEGIN
    SELECT Msg, Leitura, TipoAlerta, Hora, HoraEscrita
    FROM mensagens
    WHERE Hora >= NOW() - INTERVAL 60 MINUTE
    ORDER BY Hora DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_sensores` (IN `p_idjogo` INT(50))   BEGIN
	SELECT s.Hour, s.Sound,j.normal_noise
    FROM sound s
    JOIN jogo j ON j.IDJogo = p_idJogo
    WHERE s.IDJogo = p_idJogo AND s.Hour >= NOW() - INTERVAL 10 SECOND
    ORDER BY s.Hour DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `iniciar_jogo` (IN `p_idjogo` INT)   BEGIN
    DECLARE v_id_utilizador INT;
    DECLARE v_email VARCHAR(50);
    DECLARE timenow timestamp;

    set timenow = CURRENT_TIMESTAMP;

    SET v_email = SUBSTRING_INDEX(USER(), '@', 2);

    SELECT IDUtilizador INTO v_id_utilizador
    FROM utilizador
    WHERE Email = v_email;

    IF EXISTS (
        SELECT * FROM jogo
        WHERE IDJogo = p_idjogo
        AND Estado = 'nao_inicializado'
        AND IDUtilizador = v_id_utilizador
    ) THEN
        UPDATE jogo
        SET Estado = 'jogando', DataHoraInicio = timenow
        WHERE IDJogo = p_idjogo;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Você não tem permissão para alterar este jogo.';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `remover_utilizador` (IN `p_email` VARCHAR(50))   BEGIN
    DECLARE v_IDUtilizador INT(100);

    -- 1. Verifica se o utilizador existe e obtém o email
    SELECT IDUtilizador INTO v_IDUtilizador
    FROM utilizador
    WHERE Email = p_email;

    -- 2. Se encontrou o email, continua
    IF p_email IS NOT NULL THEN
        -- 3. Remove da tabela pisid.utilizador
        DELETE FROM utilizador WHERE IDUtilizador = v_IDUtilizador;

        -- 4. Remove o utilizador do MySQL
        SET @sql_drop = CONCAT(
            'DROP USER IF EXISTS ''', p_email, '''@''localhost'''
        );
        PREPARE stmt1 FROM @sql_drop;
        EXECUTE stmt1;
        DEALLOCATE PREPARE stmt1;
    END IF;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estrutura da tabela `jogo`
--

CREATE TABLE `jogo` (
  `IDJogo` int(11) NOT NULL,
  `NickJogador` varchar(50) DEFAULT NULL,
  `DataHoraInicio` timestamp NULL DEFAULT NULL,
  `DataHoraFim` timestamp NULL DEFAULT NULL,
  `Estado` enum('nao_inicializado','jogando','finalizado') DEFAULT NULL,
  `max_sound` float DEFAULT NULL,
  `IDUtilizador` int(11) NOT NULL,
  `normal_noise` float DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `jogo`
--

INSERT INTO `jogo` (`IDJogo`, `NickJogador`, `DataHoraInicio`, `DataHoraFim`, `Estado`, `max_sound`, `IDUtilizador`, `normal_noise`) VALUES
(4, 'Homem de Ferro', '2025-05-09 13:34:09', NULL, 'finalizado', 21.5, 6, 19),
(5, 'ironman', '2025-05-09 12:49:55', NULL, 'nao_inicializado', 0, 6, 0),
(6, 'Hulk', '2025-05-09 15:57:13', NULL, 'jogando', 0, 6, 0),
(7, 'Hulk', '2025-05-09 15:58:04', NULL, 'nao_inicializado', 100, 6, 0),
(8, 'HulkEsmaga', '2025-05-09 16:00:59', NULL, 'nao_inicializado', 100, 6, 0),
(9, 'HulkDestroi', '2025-05-09 16:19:54', NULL, 'jogando', 100, 6, 0),
(10, 'luz', '2025-05-09 16:23:10', NULL, 'jogando', NULL, 6, NULL);

--
-- Acionadores `jogo`
--
DELIMITER $$
CREATE TRIGGER `criar_salas_apos_criar_jogo` AFTER INSERT ON `jogo` FOR EACH ROW BEGIN
  DECLARE i INT DEFAULT 0;

  -- Criação das 11 salas (de 0 a 10) para o novo jogo
  WHILE i <= 10 DO
    -- Verifica se a combinação de IDJogo_Sala e IDSala já existe na tabela
    IF NOT EXISTS (SELECT 1 FROM sala WHERE IDJogo_Sala = NEW.IDJogo AND IDSala = i) THEN
      -- Se for a sala 0, coloca valores específicos para MarsamiOdd e MarsamiEven
      IF i = 0 THEN
        INSERT INTO sala (IDJogo_Sala, IDSala, NumeroMarsamisOdd, NumeroMarsamisEven, Pontos, Gatilhos)
        VALUES (NEW.IDJogo, i, 15, 15, 0, 0);
      ELSE
        INSERT INTO sala (IDJogo_Sala, IDSala, NumeroMarsamisOdd, NumeroMarsamisEven, Pontos, Gatilhos)
        VALUES (NEW.IDJogo, i, 0, 0, 0, 0);
      END IF;
    END IF;
    SET i = i + 1;
  END WHILE;

END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estrutura da tabela `mensagens`
--

CREATE TABLE `mensagens` (
  `IDMensagem` int(11) NOT NULL,
  `Hora` timestamp NULL DEFAULT NULL,
  `Leitura` decimal(10,2) DEFAULT NULL,
  `TipoAlerta` varchar(50) DEFAULT NULL,
  `Msg` varchar(100) DEFAULT NULL,
  `IDJogo` int(11) NOT NULL,
  `HoraEscrita` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `mensagens`
--

INSERT INTO `mensagens` (`IDMensagem`, `Hora`, `Leitura`, `TipoAlerta`, `Msg`, `IDJogo`, `HoraEscrita`) VALUES
(1, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:34'),
(2, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 5: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:36'),
(3, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:38'),
(4, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 10: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:38'),
(5, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:43'),
(6, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:47'),
(7, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 5: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:47'),
(8, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 10: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:49'),
(9, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:51'),
(10, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 5: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:53'),
(11, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:55'),
(12, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:59'),
(13, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 2: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:55:59'),
(14, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:03'),
(15, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:08'),
(16, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:12'),
(17, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:16'),
(18, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 1: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:16'),
(19, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:20'),
(20, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 5: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:20'),
(21, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:24'),
(22, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:28'),
(23, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 10: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:28'),
(24, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:33'),
(25, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 5: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:35'),
(26, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 2: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:37'),
(27, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 8: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:39'),
(28, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 1: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:43'),
(29, '2025-05-09 12:56:48', 20.40, 'Aviso_Ruido', '🔔 Som elevado: 20.40 dB (≥90% do limite de 21.5)', 4, '2025-05-09 12:56:48'),
(30, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 5: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:49'),
(31, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 5: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:52'),
(32, '2025-05-09 12:56:52', 20.90, 'Perigo_Ruido', '⚠️ Som crítico: 20.90 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:56:52'),
(33, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 7: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:54'),
(34, '2025-05-09 12:56:57', 20.82, 'Aviso_Ruido', '🔔 Som elevado: 20.82 dB (≥90% do limite de 21.5)', 4, '2025-05-09 12:56:57'),
(35, '2025-05-09 12:56:58', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:56:58'),
(36, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 1: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:56:58'),
(37, '2025-05-09 12:57:03', 21.03, 'Perigo_Ruido', '⚠️ Som crítico: 21.03 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:57:03'),
(38, '2025-05-09 12:57:08', 21.14, 'Perigo_Ruido', '⚠️ Som crítico: 21.14 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:57:08'),
(39, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 3: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:57:09'),
(40, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 2: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:57:09'),
(41, '2025-05-09 12:57:13', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:57:13'),
(42, '2025-05-09 12:57:18', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:57:18'),
(43, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 3: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:57:19'),
(44, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 1: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:57:21'),
(45, '2025-05-09 12:57:23', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:57:23'),
(46, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 4: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:57:23'),
(47, '2025-05-09 12:57:28', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:57:28'),
(48, '2025-05-09 12:57:33', 20.80, 'Aviso_Ruido', '🔔 Som elevado: 20.80 dB (≥90% do limite de 21.5)', 4, '2025-05-09 12:57:33'),
(49, '2025-05-09 12:57:34', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:57:34'),
(50, '2025-05-09 12:57:39', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:57:39'),
(51, '2025-05-09 12:57:44', 20.87, 'Aviso_Ruido', '🔔 Som elevado: 20.87 dB (≥90% do limite de 21.5)', 4, '2025-05-09 12:57:44'),
(52, '2025-05-09 12:57:45', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:57:45'),
(53, '2025-05-09 12:57:50', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:57:50'),
(54, '2025-05-09 12:57:55', 20.88, 'Perigo_Ruido', '⚠️ Som crítico: 20.88 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:57:55'),
(55, '2025-05-09 12:58:00', 21.04, 'Perigo_Ruido', '⚠️ Som crítico: 21.04 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:00'),
(56, '2025-05-09 12:58:05', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:05'),
(57, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 7: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:58:07'),
(58, '2025-05-09 12:58:09', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:10'),
(59, '2025-05-09 12:58:15', 21.02, 'Perigo_Ruido', '⚠️ Som crítico: 21.02 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:15'),
(60, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 4: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:58:17'),
(61, '2025-05-09 12:58:19', 20.81, 'Aviso_Ruido', '🔔 Som elevado: 20.81 dB (≥90% do limite de 21.5)', 4, '2025-05-09 12:58:20'),
(62, '2025-05-09 12:58:20', 21.38, 'Perigo_Ruido', '⚠️ Som crítico: 21.38 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:21'),
(63, '2025-05-09 12:58:26', 21.08, 'Perigo_Ruido', '⚠️ Som crítico: 21.08 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:26'),
(64, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 6: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:58:28'),
(65, '2025-05-09 12:58:30', 20.96, 'Perigo_Ruido', '⚠️ Som crítico: 20.96 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:31'),
(66, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 7: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:58:32'),
(67, '2025-05-09 12:58:36', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:36'),
(68, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 5: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:58:36'),
(69, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 7: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:58:38'),
(70, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 5: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:58:41'),
(71, '2025-05-09 12:58:41', 20.90, 'Perigo_Ruido', '⚠️ Som crítico: 20.90 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:42'),
(72, '2025-05-09 12:58:47', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:47'),
(73, '2025-05-09 12:58:52', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:52'),
(74, '2025-05-09 12:58:57', 21.20, 'Perigo_Ruido', '⚠️ Som crítico: 21.20 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:58:57'),
(75, '2025-05-09 12:59:02', 20.85, 'Aviso_Ruido', '🔔 Som elevado: 20.85 dB (≥90% do limite de 21.5)', 4, '2025-05-09 12:59:02'),
(76, '2025-05-09 12:59:03', 21.01, 'Perigo_Ruido', '⚠️ Som crítico: 21.01 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:59:03'),
(77, '2025-05-09 12:59:08', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:59:08'),
(78, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:10'),
(79, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:10'),
(80, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:10'),
(81, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:10'),
(82, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:10'),
(83, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:10'),
(84, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:10'),
(85, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:10'),
(86, '2025-05-09 12:59:13', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:59:13'),
(87, '2025-05-09 12:59:17', 20.87, 'Aviso_Ruido', '🔔 Som elevado: 20.87 dB (≥90% do limite de 21.5)', 4, '2025-05-09 12:59:18'),
(88, '2025-05-09 12:59:19', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:59:19'),
(89, '2025-05-09 12:59:24', 20.80, 'Aviso_Ruido', '🔔 Som elevado: 20.80 dB (≥90% do limite de 21.5)', 4, '2025-05-09 12:59:24'),
(90, '2025-05-09 12:59:25', 21.09, 'Perigo_Ruido', '⚠️ Som crítico: 21.09 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:59:25'),
(91, '2025-05-09 12:59:30', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:59:30'),
(92, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 3: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:30'),
(93, '2025-05-09 12:59:35', 20.80, 'Aviso_Ruido', '🔔 Som elevado: 20.80 dB (≥90% do limite de 21.5)', 4, '2025-05-09 12:59:35'),
(94, '2025-05-09 12:59:36', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:59:36'),
(95, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:37'),
(96, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:37'),
(97, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 7: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:37'),
(98, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:39'),
(99, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:39'),
(100, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:39'),
(101, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:39'),
(102, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:39'),
(103, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:39'),
(104, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:39'),
(105, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:39'),
(106, '2025-05-09 12:59:41', 21.18, 'Perigo_Ruido', '⚠️ Som crítico: 21.18 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:59:41'),
(107, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:42'),
(108, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:42'),
(109, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:42'),
(110, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:42'),
(111, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:42'),
(112, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:42'),
(113, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:42'),
(114, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:42'),
(115, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 3: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:42'),
(116, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(117, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(118, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(119, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(120, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(121, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(122, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(123, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(124, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(125, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(126, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(127, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:44'),
(128, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:45'),
(129, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:45'),
(130, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:45'),
(131, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:45'),
(132, '2025-05-09 12:59:46', 21.00, 'Perigo_Ruido', '⚠️ Som crítico: 21.00 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:59:46'),
(133, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:49'),
(134, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:49'),
(135, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:50'),
(136, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:50'),
(137, '2025-05-09 12:59:50', 20.60, 'Aviso_Ruido', '🔔 Som elevado: 20.60 dB (≥90% do limite de 21.5)', 4, '2025-05-09 12:59:51'),
(138, '2025-05-09 12:59:53', 21.14, 'Perigo_Ruido', '⚠️ Som crítico: 21.14 dB (≥95% do limite de 21.5)', 4, '2025-05-09 12:59:53'),
(139, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:54'),
(140, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:54'),
(141, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:54'),
(142, NULL, 0.00, 'Alerta Igualdade', 'Sala de destino 0: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:54'),
(143, NULL, 0.00, 'Alerta Igualdade', 'Sala de origem 6: Número de Marsamis Even e Odd iguais.', 4, '2025-05-09 12:59:54'),
(144, '2025-05-09 12:59:58', 20.60, 'Aviso_Ruido', '🔔 Som elevado: 20.60 dB (≥90% do limite de 21.5)', 4, '2025-05-09 12:59:58'),
(145, '2025-05-09 13:00:04', 20.32, 'Aviso_Ruido', '🔔 Som elevado: 20.32 dB (≥90% do limite de 21.5)', 4, '2025-05-09 13:00:04');

-- --------------------------------------------------------

--
-- Estrutura da tabela `movement`
--

CREATE TABLE `movement` (
  `IDMovement` int(11) NOT NULL,
  `Marsami` varchar(50) DEFAULT NULL,
  `RoomOrigin` varchar(50) DEFAULT NULL,
  `RoomDestiny` varchar(50) DEFAULT NULL,
  `Status` varchar(50) DEFAULT NULL,
  `IDJogo` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `movement`
--

INSERT INTO `movement` (`IDMovement`, `Marsami`, `RoomOrigin`, `RoomDestiny`, `Status`, `IDJogo`) VALUES
(1, '1', '0', '10', '1', 4),
(3, '7', '0', '1', '1', 4),
(4, '8', '0', '5', '1', 4),
(5, '1', '0', '1', '1', 4),
(6, '2', '0', '4', '1', 4),
(7, '3', '0', '5', '1', 4),
(8, '4', '0', '10', '1', 4),
(9, '5', '0', '3', '1', 4),
(10, '6', '0', '4', '1', 4),
(11, '7', '0', '2', '1', 4),
(12, '8', '0', '5', '1', 4),
(13, '9', '0', '10', '1', 4),
(14, '10', '0', '7', '1', 4),
(15, '11', '0', '5', '1', 4),
(16, '12', '0', '4', '1', 4),
(17, '13', '0', '8', '1', 4),
(18, '14', '0', '2', '1', 4),
(19, '15', '0', '2', '1', 4),
(20, '16', '0', '7', '1', 4),
(21, '17', '0', '8', '1', 4),
(22, '18', '0', '4', '1', 4),
(23, '19', '0', '6', '1', 4),
(24, '20', '0', '8', '1', 4),
(25, '21', '0', '10', '1', 4),
(26, '22', '0', '1', '1', 4),
(27, '23', '0', '7', '1', 4),
(28, '24', '0', '5', '1', 4),
(29, '25', '0', '6', '1', 4),
(30, '26', '0', '7', '1', 4),
(31, '27', '0', '1', '1', 4),
(32, '28', '0', '10', '1', 4),
(33, '29', '0', '4', '1', 4),
(34, '30', '0', '6', '1', 4),
(35, '29', '4', '5', '1', 4),
(36, '15', '2', '4', '1', 4),
(37, '13', '8', '10', '1', 4),
(38, '8', '5', '7', '1', 4),
(39, '28', '10', '1', '1', 4),
(40, '7', '2', '4', '1', 4),
(41, '20', '8', '9', '1', 4),
(42, '8', '7', '5', '1', 4),
(43, '29', '5', '7', '1', 4),
(44, '10', '7', '5', '1', 4),
(45, '9', '10', '1', '1', 4),
(46, '1', '1', '3', '1', 4),
(47, '11', '5', '7', '1', 4),
(48, '28', '1', '3', '1', 4),
(49, '1', '3', '2', '1', 4),
(50, '1', '2', '4', '1', 4),
(51, '28', '3', '2', '1', 4),
(52, '2', '5', '3', '1', 4),
(53, '9', '1', '3', '1', 4),
(54, '12', '4', '5', '1', 4),
(55, '18', '4', '5', '1', 4),
(56, '15', '5', '7', '1', 4),
(57, '14', '2', '5', '1', 4),
(58, '29', '7', '5', '1', 4),
(59, '18', '5', '7', '1', 4),
(60, '7', '4', '5', '1', 4),
(61, '18', '5', '7', '1', 4),
(62, '25', '6', '8', '1', 4),
(63, '3', '5', '7', '1', 4),
(64, '5', '2', '5', '1', 4),
(65, '15', '7', '5', '1', 4),
(66, '5', '5', '7', '1', 4),
(67, '2', '5', '7', '1', 4),
(68, '28', '2', '5', '1', 4),
(69, '15', '5', '3', '1', 4),
(70, '6', '0', '0', '2', 4),
(71, '6', '0', '0', '0', 4),
(72, '8', '0', '0', '2', 4),
(73, '8', '0', '0', '0', 4),
(74, '26', '5', '3', '1', 4),
(75, '19', '6', '8', '1', 4),
(76, '22', '1', '3', '1', 4),
(77, '13', '0', '0', '0', 4),
(78, '24', '7', '5', '1', 4),
(79, '14', '0', '0', '2', 4),
(80, '14', '0', '0', '0', 4),
(81, '19', '0', '0', '2', 4),
(82, '19', '0', '0', '0', 4),
(83, '28', '5', '3', '1', 4),
(84, '23', '0', '0', '2', 4),
(85, '23', '0', '0', '0', 4),
(86, '21', '0', '0', '2', 4),
(87, '21', '0', '0', '0', 4),
(88, '29', '5', '3', '1', 4),
(89, '2', '0', '0', '2', 4),
(90, '2', '0', '0', '0', 4),
(91, '15', '0', '0', '2', 4),
(92, '15', '0', '0', '0', 4),
(93, '22', '0', '0', '2', 4),
(94, '22', '0', '0', '0', 4),
(95, '20', '0', '0', '2', 4),
(96, '20', '0', '0', '0', 4),
(97, '27', '5', '7', '1', 4),
(98, '26', '0', '0', '2', 4),
(99, '26', '0', '0', '0', 4),
(100, '28', '3', '2', '1', 4),
(101, '29', '2', '5', '1', 4),
(102, '12', '0', '0', '2', 4),
(103, '12', '0', '0', '0', 4),
(104, '30', '6', '8', '1', 4);

--
-- Acionadores `movement`
--
DELIMITER $$
CREATE TRIGGER `atualizar_ocupacao_movimento` AFTER INSERT ON `movement` FOR EACH ROW BEGIN
    DECLARE marsami_num INT;
    SET marsami_num = CAST(NEW.Marsami AS UNSIGNED);

    -- Atualiza sala de origem
    IF (marsami_num % 2 = 0) THEN
        UPDATE sala 
        SET NumeroMarsamisEven = IFNULL(NumeroMarsamisEven, 0) - 1 
        WHERE IDSala = NEW.RoomOrigin;
    ELSE
        UPDATE sala 
        SET NumeroMarsamisOdd = IFNULL(NumeroMarsamisOdd, 0) - 1 
        WHERE IDSala = NEW.RoomOrigin;
    END IF;

    -- Atualiza sala de destino
    IF (marsami_num % 2 = 0) THEN
        UPDATE sala 
        SET NumeroMarsamisEven = IFNULL(NumeroMarsamisEven, 0) + 1 
        WHERE IDSala = NEW.RoomDestiny;
    ELSE
        UPDATE sala 
        SET NumeroMarsamisOdd = IFNULL(NumeroMarsamisOdd, 0) + 1 
        WHERE IDSala = NEW.RoomDestiny;
    END IF;

    -- Verifica a sala de origem
    IF EXISTS (
        SELECT 1 FROM sala 
        WHERE IDSala = NEW.RoomOrigin
          AND IFNULL(NumeroMarsamisEven,0) = IFNULL(NumeroMarsamisOdd,0)
    ) THEN
        INSERT INTO mensagens (IDJogo, Hora,Leitura, TipoAlerta, Msg, HoraEscrita)
        VALUES (NEW.IDJogo, null, 0, 'Alerta Igualdade', 
                CONCAT('Sala de origem ', NEW.RoomOrigin, ': Número de Marsamis Even e Odd iguais.'), 
                NOW());
    END IF;

    -- Verifica a sala de destino
    IF EXISTS (
        SELECT 1 FROM sala 
        WHERE IDSala = NEW.RoomDestiny 
          AND IFNULL(NumeroMarsamisEven,0) = IFNULL(NumeroMarsamisOdd,0)
    ) THEN
        INSERT INTO mensagens (IDJogo, Hora, Leitura, TipoAlerta, Msg, HoraEscrita)
        VALUES (NEW.IDJogo, null, 0, 'Alerta Igualdade', 
                CONCAT('Sala de destino ', NEW.RoomDestiny, ': Número de Marsamis Even e Odd iguais.'), 
                NOW());
    END IF;

END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estrutura da tabela `sala`
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
-- Extraindo dados da tabela `sala`
--

INSERT INTO `sala` (`IDJogo_Sala`, `IDSala`, `NumeroMarsamisOdd`, `NumeroMarsamisEven`, `Pontos`, `Gatilhos`) VALUES
(4, 0, -2, -1, 0, 0),
(5, 0, 0, 0, 0, 0),
(6, 0, 15, 15, 0, 0),
(7, 0, 15, 15, 0, 0),
(8, 0, 15, 15, 0, 0),
(9, 0, 15, 15, 0, 0),
(10, 0, 15, 15, 0, 0),
(4, 1, 2, 0, 0, 0),
(5, 1, 1, 0, 0, 0),
(6, 1, 0, 0, 0, 0),
(7, 1, 0, 0, 0, 0),
(8, 1, 0, 0, 0, 0),
(9, 1, 0, 0, 0, 0),
(10, 1, 0, 0, 0, 0),
(4, 2, -2, 1, 0, 0),
(5, 2, -2, 1, 0, 0),
(6, 2, 0, 0, 0, 0),
(7, 2, 0, 0, 0, 0),
(8, 2, 0, 0, 0, 0),
(9, 2, 0, 0, 0, 0),
(10, 2, 0, 0, 0, 0),
(4, 3, 4, 3, 0, 0),
(5, 3, 4, 3, 0, 0),
(6, 3, 0, 0, 0, 0),
(7, 3, 0, 0, 0, 0),
(8, 3, 0, 0, 0, 0),
(9, 3, 0, 0, 0, 0),
(10, 3, 0, 0, 0, 0),
(4, 4, 2, 2, 0, 0),
(5, 4, 2, 2, 0, 0),
(6, 4, 0, 0, 0, 0),
(7, 4, 0, 0, 0, 0),
(8, 4, 0, 0, 0, 0),
(9, 4, 0, 0, 0, 0),
(10, 4, 0, 0, 0, 0),
(4, 5, 0, 3, 0, 0),
(5, 5, 0, 2, 0, 0),
(6, 5, 0, 0, 0, 0),
(7, 5, 0, 0, 0, 0),
(8, 5, 0, 0, 0, 0),
(9, 5, 0, 0, 0, 0),
(10, 5, 0, 0, 0, 0),
(4, 6, 0, 0, 0, 0),
(5, 6, 0, 0, 0, 0),
(6, 6, 0, 0, 0, 0),
(7, 6, 0, 0, 0, 0),
(8, 6, 0, 0, 0, 0),
(9, 6, 0, 0, 0, 0),
(10, 6, 0, 0, 0, 0),
(4, 7, 5, 4, 0, 0),
(5, 7, 5, 4, 0, 0),
(6, 7, 0, 0, 0, 0),
(7, 7, 0, 0, 0, 0),
(8, 7, 0, 0, 0, 0),
(9, 7, 0, 0, 0, 0),
(10, 7, 0, 0, 0, 0),
(4, 8, 3, 1, 0, 0),
(5, 8, 3, 1, 0, 0),
(6, 8, 0, 0, 0, 0),
(7, 8, 0, 0, 0, 0),
(8, 8, 0, 0, 0, 0),
(9, 8, 0, 0, 0, 0),
(10, 8, 0, 0, 0, 0),
(4, 9, 0, 1, 0, 0),
(5, 9, 0, 1, 0, 0),
(6, 9, 0, 0, 0, 0),
(7, 9, 0, 0, 0, 0),
(8, 9, 0, 0, 0, 0),
(9, 9, 0, 0, 0, 0),
(10, 9, 0, 0, 0, 0),
(4, 10, 3, 1, 0, 0),
(5, 10, 2, 1, 0, 0),
(6, 10, 0, 0, 0, 0),
(7, 10, 0, 0, 0, 0),
(8, 10, 0, 0, 0, 0),
(9, 10, 0, 0, 0, 0),
(10, 10, 0, 0, 0, 0);

-- --------------------------------------------------------

--
-- Estrutura da tabela `sound`
--

CREATE TABLE `sound` (
  `IDSound` int(11) NOT NULL,
  `Hour` datetime DEFAULT NULL,
  `Sound` float DEFAULT NULL,
  `IDJogo` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Extraindo dados da tabela `sound`
--

INSERT INTO `sound` (`IDSound`, `Hour`, `Sound`, `IDJogo`) VALUES
(1, '2025-05-09 13:56:36', 19.2473, 4),
(2, '2025-05-09 13:56:37', 19.4, 4),
(3, '2025-05-09 13:56:38', 19.7886, 4),
(4, '2025-05-09 13:56:39', 19.6, 4),
(5, '2025-05-09 13:56:40', 19.8, 4),
(6, '2025-05-09 13:56:41', 19.8, 4),
(7, '2025-05-09 13:56:42', 20, 4),
(8, '2025-05-09 13:56:43', 20.1272, 4),
(9, '2025-05-09 13:56:44', 20.3678, 4),
(10, '2025-05-09 13:56:46', 20.2, 4),
(11, '2025-05-09 13:56:47', 20.4, 4),
(12, '2025-05-09 13:56:48', 20.4, 4),
(13, '2025-05-09 13:56:51', 20.8, 4),
(14, '2025-05-09 13:56:52', 20.9038, 4),
(15, '2025-05-09 13:56:53', 21, 4),
(16, '2025-05-09 13:56:54', 21, 4),
(17, '2025-05-09 13:56:55', 21, 4),
(18, '2025-05-09 13:56:57', 20.8205, 4),
(19, '2025-05-09 13:56:58', 21, 4),
(20, '2025-05-09 13:56:59', 20.9002, 4),
(21, '2025-05-09 13:57:00', 20.9502, 4),
(22, '2025-05-09 13:57:01', 21, 4),
(23, '2025-05-09 13:57:02', 21, 4),
(24, '2025-05-09 13:57:03', 21.0254, 4),
(25, '2025-05-09 13:57:04', 20.9227, 4),
(26, '2025-05-09 13:57:05', 21.2, 4),
(27, '2025-05-09 13:57:08', 21.1404, 4),
(28, '2025-05-09 13:57:09', 21, 4),
(29, '2025-05-09 13:57:10', 21.2, 4),
(30, '2025-05-09 13:57:11', 21, 4),
(31, '2025-05-09 13:57:12', 21.2, 4),
(32, '2025-05-09 13:57:13', 21, 4),
(33, '2025-05-09 13:57:14', 20.9156, 4),
(34, '2025-05-09 13:57:15', 20.9935, 4),
(35, '2025-05-09 13:57:16', 21, 4),
(36, '2025-05-09 13:57:18', 21, 4),
(37, '2025-05-09 13:57:19', 21, 4),
(38, '2025-05-09 13:57:20', 21, 4),
(39, '2025-05-09 13:57:21', 21, 4),
(40, '2025-05-09 13:57:22', 20.9713, 4),
(41, '2025-05-09 13:57:23', 21, 4),
(42, '2025-05-09 13:57:24', 21, 4),
(43, '2025-05-09 13:57:25', 21, 4),
(44, '2025-05-09 13:57:27', 21.1395, 4),
(45, '2025-05-09 13:57:28', 21, 4),
(46, '2025-05-09 13:57:29', 21.0196, 4),
(47, '2025-05-09 13:57:30', 21, 4),
(48, '2025-05-09 13:57:31', 21, 4),
(49, '2025-05-09 13:57:32', 21, 4),
(50, '2025-05-09 13:57:33', 20.8, 4),
(51, '2025-05-09 13:57:34', 21, 4),
(52, '2025-05-09 13:57:35', 20.8, 4),
(53, '2025-05-09 13:57:37', 21.1857, 4),
(54, '2025-05-09 13:57:38', 20.8, 4),
(55, '2025-05-09 13:57:39', 21, 4),
(56, '2025-05-09 13:57:40', 21, 4),
(57, '2025-05-09 13:57:41', 21, 4),
(58, '2025-05-09 13:57:42', 21.1425, 4),
(59, '2025-05-09 13:57:43', 20.8084, 4),
(60, '2025-05-09 13:57:44', 20.8684, 4),
(61, '2025-05-09 13:57:45', 21, 4),
(62, '2025-05-09 13:57:46', 21.2, 4),
(63, '2025-05-09 13:57:47', 21, 4),
(64, '2025-05-09 13:57:49', 21.2, 4),
(65, '2025-05-09 13:57:50', 21, 4),
(66, '2025-05-09 13:57:51', 21.2, 4),
(67, '2025-05-09 13:57:52', 21, 4),
(68, '2025-05-09 13:57:53', 21.2, 4),
(69, '2025-05-09 13:57:54', 21, 4),
(70, '2025-05-09 13:57:55', 20.8784, 4),
(71, '2025-05-09 13:57:56', 20.88, 4),
(72, '2025-05-09 13:57:57', 21.0252, 4),
(73, '2025-05-09 13:57:58', 21, 4),
(74, '2025-05-09 13:58:00', 21.043, 4),
(75, '2025-05-09 13:58:01', 21.0441, 4),
(76, '2025-05-09 13:58:02', 21, 4),
(77, '2025-05-09 13:58:03', 21, 4),
(78, '2025-05-09 13:58:04', 21.2, 4),
(79, '2025-05-09 13:58:05', 21, 4),
(80, '2025-05-09 13:58:06', 20.9778, 4),
(81, '2025-05-09 13:58:07', 20.9802, 4),
(82, '2025-05-09 13:58:08', 20.9794, 4),
(83, '2025-05-09 13:58:09', 21, 4),
(84, '2025-05-09 13:58:11', 20.9385, 4),
(85, '2025-05-09 13:58:12', 21, 4),
(86, '2025-05-09 13:58:13', 21, 4),
(87, '2025-05-09 13:58:14', 21.1342, 4),
(88, '2025-05-09 13:58:15', 21.0153, 4),
(89, '2025-05-09 13:58:16', 20.9521, 4),
(90, '2025-05-09 13:58:17', 20.9097, 4),
(91, '2025-05-09 13:58:18', 21, 4),
(92, '2025-05-09 13:58:19', 20.8055, 4),
(93, '2025-05-09 13:58:20', 21.3823, 4),
(94, '2025-05-09 13:58:22', 21, 4),
(95, '2025-05-09 13:58:23', 21.2, 4),
(96, '2025-05-09 13:58:24', 21, 4),
(97, '2025-05-09 13:58:25', 21.2, 4),
(98, '2025-05-09 13:58:26', 21.0815, 4),
(99, '2025-05-09 13:58:27', 21.1054, 4),
(100, '2025-05-09 13:58:28', 21, 4),
(101, '2025-05-09 13:58:29', 20.9435, 4),
(102, '2025-05-09 13:58:30', 20.9638, 4),
(103, '2025-05-09 13:58:31', 21.1646, 4),
(104, '2025-05-09 13:58:33', 21, 4),
(105, '2025-05-09 13:58:34', 20.9865, 4),
(106, '2025-05-09 13:58:35', 21, 4),
(107, '2025-05-09 13:58:36', 21, 4),
(108, '2025-05-09 13:58:37', 21, 4),
(109, '2025-05-09 13:58:38', 21, 4),
(110, '2025-05-09 13:58:39', 21, 4),
(111, '2025-05-09 13:58:40', 21, 4),
(112, '2025-05-09 13:58:41', 20.9018, 4),
(113, '2025-05-09 13:58:42', 21, 4),
(114, '2025-05-09 13:58:44', 21, 4),
(115, '2025-05-09 13:58:45', 21, 4),
(116, '2025-05-09 13:58:46', 21.2459, 4),
(117, '2025-05-09 13:58:47', 21, 4),
(118, '2025-05-09 13:58:48', 21.348, 4),
(119, '2025-05-09 13:58:49', 21, 4),
(120, '2025-05-09 13:58:50', 21, 4),
(121, '2025-05-09 13:58:51', 21.0192, 4),
(122, '2025-05-09 13:58:52', 21, 4),
(123, '2025-05-09 13:58:53', 21.1875, 4),
(124, '2025-05-09 13:58:55', 21.2, 4),
(125, '2025-05-09 13:58:56', 21, 4),
(126, '2025-05-09 13:58:57', 21.2, 4),
(127, '2025-05-09 13:58:58', 21, 4),
(128, '2025-05-09 13:58:59', 21.2, 4),
(129, '2025-05-09 13:59:00', 21, 4),
(130, '2025-05-09 13:59:01', 21, 4),
(131, '2025-05-09 13:59:02', 20.8481, 4),
(132, '2025-05-09 13:59:03', 21.009, 4),
(133, '2025-05-09 13:59:04', 20.8883, 4),
(134, '2025-05-09 13:59:05', 21, 4),
(135, '2025-05-09 13:59:07', 21, 4),
(136, '2025-05-09 13:59:08', 21, 4),
(137, '2025-05-09 13:59:09', 21.094, 4),
(138, '2025-05-09 13:59:10', 21.0197, 4),
(139, '2025-05-09 13:59:11', 21, 4),
(140, '2025-05-09 13:59:12', 21.0503, 4),
(141, '2025-05-09 13:59:13', 21, 4),
(142, '2025-05-09 13:59:14', 21, 4),
(143, '2025-05-09 13:59:15', 21, 4),
(144, '2025-05-09 13:59:16', 21, 4),
(145, '2025-05-09 13:59:17', 20.8679, 4),
(146, '2025-05-09 13:59:19', 21, 4),
(147, '2025-05-09 13:59:20', 21, 4),
(148, '2025-05-09 13:59:21', 21, 4),
(149, '2025-05-09 13:59:22', 21, 4),
(150, '2025-05-09 13:59:23', 21, 4),
(151, '2025-05-09 13:59:24', 20.8, 4),
(152, '2025-05-09 13:59:25', 21.0914, 4),
(153, '2025-05-09 13:59:26', 20.8, 4),
(154, '2025-05-09 13:59:27', 21, 4),
(155, '2025-05-09 13:59:29', 20.8, 4),
(156, '2025-05-09 13:59:30', 21, 4),
(157, '2025-05-09 13:59:31', 21, 4),
(158, '2025-05-09 13:59:32', 20.9373, 4),
(159, '2025-05-09 13:59:33', 21, 4),
(160, '2025-05-09 13:59:34', 21, 4),
(161, '2025-05-09 13:59:35', 20.8, 4),
(162, '2025-05-09 13:59:36', 21, 4),
(163, '2025-05-09 13:59:37', 20.8, 4),
(164, '2025-05-09 13:59:38', 21, 4),
(165, '2025-05-09 13:59:39', 20.8678, 4),
(166, '2025-05-09 13:59:41', 21.1786, 4),
(167, '2025-05-09 13:59:42', 21.1976, 4),
(168, '2025-05-09 13:59:43', 20.8, 4),
(169, '2025-05-09 13:59:44', 21, 4),
(170, '2025-05-09 13:59:45', 20.8, 4),
(171, '2025-05-09 13:59:46', 21, 4),
(172, '2025-05-09 13:59:47', 20.8, 4),
(173, '2025-05-09 13:59:48', 20.8, 4),
(174, '2025-05-09 13:59:49', 20.796, 4),
(175, '2025-05-09 13:59:50', 20.6, 4),
(176, '2025-05-09 13:59:52', 20.8, 4),
(177, '2025-05-09 13:59:53', 21.1366, 4),
(178, '2025-05-09 13:59:54', 20.8821, 4),
(179, '2025-05-09 13:59:55', 20.9094, 4),
(180, '2025-05-09 13:59:56', 20.6724, 4),
(181, '2025-05-09 13:59:57', 20.6802, 4),
(182, '2025-05-09 13:59:58', 20.6, 4),
(183, '2025-05-09 13:59:59', 20.7065, 4),
(184, '2025-05-09 14:00:00', 20.4, 4),
(185, '2025-05-09 14:00:01', 20.4, 4),
(186, '2025-05-09 14:00:03', 20.2, 4),
(187, '2025-05-09 14:00:04', 20.3247, 4),
(188, '2025-05-09 14:00:05', 20.2, 4),
(189, '2025-05-09 14:00:06', 20, 4),
(190, '2025-05-09 14:00:07', 20.0311, 4),
(191, '2025-05-09 14:00:08', 19.8, 4),
(192, '2025-05-09 14:00:09', 19.8, 4),
(193, '2025-05-09 14:00:10', 19.611, 4),
(194, '2025-05-09 14:00:11', 19.6, 4),
(195, '2025-05-09 14:00:12', 19.4, 4),
(196, '2025-05-09 14:00:14', 19.4, 4),
(197, '2025-05-09 14:00:15', 19.3838, 4),
(198, '2025-05-09 14:00:16', 19.2, 4),
(199, '2025-05-09 14:00:17', 19.2, 4),
(200, '2025-05-09 14:00:18', 19.2, 4),
(201, '2025-05-09 14:00:19', 19.0887, 4),
(202, '2025-05-09 14:00:20', 19.2, 4);

-- --------------------------------------------------------

--
-- Estrutura da tabela `utilizador`
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
-- Extraindo dados da tabela `utilizador`
--

INSERT INTO `utilizador` (`Telemovel`, `Tipo`, `Grupo`, `Nome`, `IDUtilizador`, `Email`) VALUES
('111222333', 'jogador', 9, 'jogador', 6, 'jogador@gmail.com'),
('444555666', 'admin', 9, 'admin', 7, 'admin@gmail.com'),
('777888999', 'software', 9, 'software', 8, 'software@gmail.com');

--
-- Índices para tabelas despejadas
--

--
-- Índices para tabela `jogo`
--
ALTER TABLE `jogo`
  ADD PRIMARY KEY (`IDJogo`),
  ADD KEY `IDUtilizador_Jogo` (`IDUtilizador`) USING BTREE;

--
-- Índices para tabela `mensagens`
--
ALTER TABLE `mensagens`
  ADD PRIMARY KEY (`IDMensagem`) USING BTREE,
  ADD KEY `IDJogo_Mensagens` (`IDJogo`) USING BTREE;

--
-- Índices para tabela `movement`
--
ALTER TABLE `movement`
  ADD PRIMARY KEY (`IDMovement`),
  ADD KEY `IDJogo_Movement` (`IDJogo`) USING BTREE;

--
-- Índices para tabela `sala`
--
ALTER TABLE `sala`
  ADD PRIMARY KEY (`IDSala`,`IDJogo_Sala`) USING BTREE,
  ADD KEY `IDJogo_Sala` (`IDJogo_Sala`) USING BTREE;

--
-- Índices para tabela `sound`
--
ALTER TABLE `sound`
  ADD PRIMARY KEY (`IDSound`),
  ADD KEY `IDJogo_Sound` (`IDJogo`) USING BTREE;

--
-- Índices para tabela `utilizador`
--
ALTER TABLE `utilizador`
  ADD PRIMARY KEY (`IDUtilizador`),
  ADD UNIQUE KEY `Email` (`Email`);

--
-- AUTO_INCREMENT de tabelas despejadas
--

--
-- AUTO_INCREMENT de tabela `jogo`
--
ALTER TABLE `jogo`
  MODIFY `IDJogo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de tabela `mensagens`
--
ALTER TABLE `mensagens`
  MODIFY `IDMensagem` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=146;

--
-- AUTO_INCREMENT de tabela `movement`
--
ALTER TABLE `movement`
  MODIFY `IDMovement` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=105;

--
-- AUTO_INCREMENT de tabela `sound`
--
ALTER TABLE `sound`
  MODIFY `IDSound` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=203;

--
-- AUTO_INCREMENT de tabela `utilizador`
--
ALTER TABLE `utilizador`
  MODIFY `IDUtilizador` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- Restrições para despejos de tabelas
--

--
-- Limitadores para a tabela `jogo`
--
ALTER TABLE `jogo`
  ADD CONSTRAINT `IDUtilizador_Jogo` FOREIGN KEY (`IDUtilizador`) REFERENCES `utilizador` (`IDUtilizador`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `mensagens`
--
ALTER TABLE `mensagens`
  ADD CONSTRAINT `IDJogo_Mensagens` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `movement`
--
ALTER TABLE `movement`
  ADD CONSTRAINT `IDJogo_Movement` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `sala`
--
ALTER TABLE `sala`
  ADD CONSTRAINT `IDJogo_Sala` FOREIGN KEY (`IDJogo_Sala`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Limitadores para a tabela `sound`
--
ALTER TABLE `sound`
  ADD CONSTRAINT `IDJogo_Sound` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
