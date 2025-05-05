import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import './HomePage.css';

function HomePage() {
    const navigate = useNavigate();

    const [jogos, setJogos] = useState([]);
    const [jogoSelecionado, setJogoSelecionado] = useState("");

    const [user] = useState(() => {
        const storedUser = localStorage.getItem('user');
        return storedUser ? JSON.parse(storedUser) : null;
    });

    useEffect(() => {
        if (!user) {
            navigate('/');
            return;
        }

        // Chamada à API que retorna jogos do utilizador
        axios.get(`http://localhost/getJogos.php?idUtilizador=${user.id}`)
            .then(res => setJogos(res.data))
            .catch(err => console.error('Erro ao carregar jogos:', err));
    }, [user, navigate]);

    const handleLogout = () => {
        localStorage.removeItem('user');
        navigate('/');
    };

    const handleAlterarClick = () => {
        if (jogoSelecionado) {
            navigate('/alterar-jogo', { state: { idJogo: jogoSelecionado } });
        }
    };

    return (
        <div className="home-container">
            <header className="home-header">
                <h2>Bem-vindo, {user?.nome} ({user?.email})</h2>
            </header>

            <main className="home-content">
                <h2>Jogos do Utilizador</h2>
                {jogos.length === 0 ? (
                    <p>Nenhum jogo encontrado para alterar.</p>
                ) : (
                    <>
                        <label>Selecione o jogo que pretende alterar:</label>
                        <select onChange={(e) => setJogoSelecionado(e.target.value)} value={jogoSelecionado}>
                            <option value="">Selecione um jogo</option>
                            {jogos.map((jogo) => (
                                <option key={jogo.IDJogo} value={jogo.IDJogo}>
                                    {jogo.NickJogador}
                                </option>
                            ))}
                        </select>
                        <button onClick={handleAlterarClick} disabled={!jogoSelecionado}>
                            Alterar Jogo
                        </button>
                    </>
                )}
                <button onClick={() => navigate('/criar-jogo')}>Criar Jogo</button>
                <button onClick={handleLogout}>Logout</button>
            </main>
        </div>
    );
}

export default HomePage;
