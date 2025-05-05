import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import { BrowserRouter, Routes, Route } from "react-router-dom";
import reportWebVitals from './reportWebVitals';
import LoginForm from './LoginForm';
import HomePage from './HomePage';
import AlterarJogo from './AlterarJogo';
import CriarJogo from './CriarJogo';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <BrowserRouter>
    <Routes>
      <Route path="/" element={<App />} />
      <Route path="/LoginForm" element={<LoginForm />} />
      <Route path="/home" element={<HomePage />} />
      <Route path="/alterar-jogo" element={<AlterarJogo />} />
      <Route path="/criar-jogo" element={<CriarJogo />} />
    </Routes>
  </BrowserRouter>
);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
