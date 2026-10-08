import React, { useState, useEffect } from 'react';
import { socket } from '../socket';
import { SOCKET_EVENTS } from '@shared/events';
import { HealthResponse } from '@shared/types';
import { Activity, Wifi, Server, CheckCircle2, XCircle, RefreshCw, ArrowLeft, Smartphone, Laptop } from 'lucide-react';

export const NetworkTest: React.FC = () => {
  const [socketConnected, setSocketConnected] = useState(socket.connected);
  const [socketPing, setSocketPing] = useState<number | null>(null);
  const [healthData, setHealthData] = useState<HealthResponse | null>(null);
  const [healthError, setHealthError] = useState<string | null>(null);
  const [isTesting, setIsTesting] = useState(false);
  const [testLog, setTestLog] = useState<string[]>([]);

  const addLog = (msg: string) => {
    setTestLog(prev => [...prev.slice(-15), `[${new Date().toLocaleTimeString()}] ${msg}`]);
  };

  const checkHealth = async () => {
    try {
      addLog('GET /api/health lekérdezése...');
      const res = await fetch('/api/health');
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: HealthResponse = await res.json();
      setHealthData(data);
      setHealthError(null);
      addLog(`Egészség OK: szerver=${data.server}, LAN IP=${data.lanIp}:${data.port}`);
      return true;
    } catch (err: any) {
      setHealthError(err.message || 'Sikertelen kérés');
      addLog(`HIBA /api/health lekérésnél: ${err.message}`);
      return false;
    }
  };

  const measurePing = () => {
    return new Promise<number>((resolve) => {
      const startTime = performance.now();
      addLog('Socket ping mérése...');

      const handlePong = (data: { timestamp: number }) => {
        const latency = Math.round(performance.now() - startTime);
        socket.off(SOCKET_EVENTS.PONG_CHECK, handlePong);
        setSocketPing(latency);
        addLog(`Socket válasz érkezett: ${latency} ms`);
        resolve(latency);
      };

      socket.on(SOCKET_EVENTS.PONG_CHECK, handlePong);
      socket.emit(SOCKET_EVENTS.PING_CHECK, { timestamp: Date.now() });

      // Fallback timeout
      setTimeout(() => {
        socket.off(SOCKET_EVENTS.PONG_CHECK, handlePong);
        resolve(-1);
      }, 3000);
    });
  };

  const runAllTests = async () => {
    setIsTesting(true);
    addLog('--- HÁLÓZATI TESZT INDÍTÁSA ---');
    if (!socket.connected) {
      addLog('Socket nem csatlakozott, újrakapcsolódás kísérlete...');
      socket.connect();
    }
    await checkHealth();
    await measurePing();
    setIsTesting(false);
    addLog('--- TESZT BEFEJEZŐDÖTT ---');
  };

  useEffect(() => {
    const onConnect = () => {
      setSocketConnected(true);
      addLog('Socket.IO csatlakozva');
    };
    const onDisconnect = () => {
      setSocketConnected(false);
      addLog('Socket.IO lecsatlakozva');
    };

    socket.on('connect', onConnect);
    socket.on('disconnect', onDisconnect);

    runAllTests();

    return () => {
      socket.off('connect', onConnect);
      socket.off('disconnect', onDisconnect);
    };
  }, []);

  return (
    <div className="min-h-screen bg-slate-950 text-white p-4 lg:p-8 flex flex-col items-center">
      <div className="w-full max-w-xl flex flex-col gap-5">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-slate-800">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-cyan-500/20 text-cyan-400 flex items-center justify-center">
              <Activity className="w-6 h-6 animate-pulse" />
            </div>
            <div>
              <h1 className="text-xl font-black font-heading tracking-wide text-cyan-300">
                HÁLÓZATI DEBUG & DIAGNOSZTIKA
              </h1>
              <p className="text-xs text-slate-400 font-bold">Party Mayhem LAN Connectivity Test</p>
            </div>
          </div>
          <button
            onClick={() => (window.location.href = '/')}
            className="p-2 rounded-xl bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800"
            title="Vissza a főoldalra"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
        </div>

        {/* Big Test Button */}
        <button
          onClick={runAllTests}
          disabled={isTesting}
          className={`w-full py-4 rounded-2xl font-black text-lg flex items-center justify-center gap-3 shadow-xl transition-all ${
            isTesting
              ? 'bg-slate-800 text-slate-400 cursor-not-allowed'
              : 'bg-gradient-to-r from-cyan-500 to-blue-600 hover:brightness-110 active:scale-95 text-slate-950 shadow-cyan-500/20'
          }`}
        >
          <RefreshCw className={`w-5 h-5 ${isTesting ? 'animate-spin' : ''}`} />
          <span>{isTesting ? 'TESZTELÉS FOLYAMATBAN...' : 'TEST CONNECTION'}</span>
        </button>

        {/* Connection Diagnostics Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
          {/* 1. Origin Info */}
          <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-4 flex flex-col gap-1">
            <span className="text-[10px] font-black tracking-widest uppercase text-slate-400">
              Böngésző Origin
            </span>
            <span className="font-mono text-sm font-bold text-amber-300 truncate">
              {window.location.origin}
            </span>
            <div className="text-[11px] text-slate-400 mt-1 flex flex-col">
              <span>Host: <b className="text-slate-200">{window.location.hostname}</b></span>
              <span>Port: <b className="text-slate-200">{window.location.port || '80/443'}</b></span>
            </div>
          </div>

          {/* 2. Socket.IO Status */}
          <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-4 flex flex-col justify-between">
            <span className="text-[10px] font-black tracking-widest uppercase text-slate-400">
              Socket.IO Státusz
            </span>
            <div className="flex items-center gap-2 my-1">
              {socketConnected ? (
                <>
                  <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                  <span className="text-base font-black text-emerald-300">CSATLAKOZVA</span>
                </>
              ) : (
                <>
                  <XCircle className="w-5 h-5 text-red-400" />
                  <span className="text-base font-black text-red-300">SZAKADT</span>
                </>
              )}
            </div>
            <span className="text-xs font-mono text-slate-400">
              Ping latency:{' '}
              <b className={socketPing !== null && socketPing > 0 ? 'text-cyan-300' : 'text-slate-500'}>
                {socketPing !== null ? (socketPing >= 0 ? `${socketPing} ms` : 'Időtúllépés') : 'Mérés...'}
              </b>
            </span>
          </div>

          {/* 3. Server Health */}
          <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-4 flex flex-col gap-1 sm:col-span-2">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-black tracking-widest uppercase text-slate-400">
                Szerver Health (/api/health)
              </span>
              <span className={`text-xs font-black ${healthData ? 'text-emerald-400' : 'text-red-400'}`}>
                {healthData ? 'ONLINE' : 'ELÉRHETETLEN'}
              </span>
            </div>
            {healthData ? (
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mt-1 text-xs">
                <div className="bg-slate-950/60 p-2 rounded-xl">
                  <span className="text-slate-400 text-[10px] block">Szerver:</span>
                  <span className="font-bold text-white truncate block">{healthData.server}</span>
                </div>
                <div className="bg-slate-950/60 p-2 rounded-xl">
                  <span className="text-slate-400 text-[10px] block">LAN IP:</span>
                  <span className="font-mono font-bold text-amber-300">{healthData.lanIp}</span>
                </div>
                <div className="bg-slate-950/60 p-2 rounded-xl">
                  <span className="text-slate-400 text-[10px] block">Port:</span>
                  <span className="font-mono font-bold text-white">{healthData.port}</span>
                </div>
                <div className="bg-slate-950/60 p-2 rounded-xl">
                  <span className="text-slate-400 text-[10px] block">Uptime:</span>
                  <span className="font-mono font-bold text-slate-300">{healthData.uptime}s</span>
                </div>
              </div>
            ) : (
              <p className="text-xs text-red-400 font-mono mt-1">
                Hiba: {healthError || 'A backend nem válaszol az /api/health végponton.'}
              </p>
            )}
          </div>
        </div>

        {/* Real-time Diagnostics Log */}
        <div className="bg-slate-900/90 border border-slate-800 rounded-2xl p-4 flex flex-col gap-2">
          <span className="text-[10px] font-black tracking-widest uppercase text-slate-400">
            Diagnosztikai Napló
          </span>
          <div className="bg-black/60 rounded-xl p-3 font-mono text-[11px] text-slate-300 h-36 overflow-y-auto space-y-1">
            {testLog.length === 0 ? (
              <span className="text-slate-600">Nincs naplóbejegyzés...</span>
            ) : (
              testLog.map((log, i) => <div key={i}>{log}</div>)
            )}
          </div>
        </div>

        {/* Quick Nav Buttons */}
        <div className="grid grid-cols-2 gap-3">
          <button
            onClick={() => (window.location.href = '/join')}
            className="py-3 px-4 rounded-xl bg-amber-500/20 border border-amber-500/40 hover:bg-amber-500/30 text-amber-300 font-bold text-xs flex items-center justify-center gap-2"
          >
            <Smartphone className="w-4 h-4" />
            <span>Tovább a /join oldalra</span>
          </button>
          <button
            onClick={() => (window.location.href = '/host')}
            className="py-3 px-4 rounded-xl bg-purple-500/20 border border-purple-500/40 hover:bg-purple-500/30 text-purple-300 font-bold text-xs flex items-center justify-center gap-2"
          >
            <Laptop className="w-4 h-4" />
            <span>Tovább a /host oldalra</span>
          </button>
        </div>
      </div>
    </div>
  );
};
