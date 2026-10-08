import React, { useEffect, useState } from 'react';
import QRCode from 'qrcode';

interface QRCodeDisplayProps {
  url: string;
  size?: number;
}

export const QRCodeDisplay: React.FC<QRCodeDisplayProps> = ({ url, size = 260 }) => {
  const [dataUrl, setDataUrl] = useState<string>('');

  useEffect(() => {
    QRCode.toDataURL(url, {
      width: size,
      margin: 2,
      color: {
        dark: '#0f172a',
        light: '#ffffff'
      }
    })
      .then(setDataUrl)
      .catch(console.error);
  }, [url, size]);

  if (!dataUrl) {
    return (
      <div 
        style={{ width: size, height: size }} 
        className="bg-white/10 rounded-2xl flex items-center justify-center animate-pulse"
      >
        <span className="text-slate-400 font-bold">QR Generálás...</span>
      </div>
    );
  }

  return (
    <div className="bg-white p-3 rounded-3xl shadow-2xl border-4 border-amber-400/80 inline-block transform transition hover:scale-105">
      <img src={dataUrl} alt="Join QR Code" className="rounded-xl block" width={size} height={size} />
    </div>
  );
};
