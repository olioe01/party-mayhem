import React, { Component, ErrorInfo, ReactNode } from 'react';
import { AlertTriangle } from 'lucide-react';

interface Props {
  fallback: ReactNode;
  children: ReactNode;
  minigameId?: string;
}

interface State {
  hasError: boolean;
  error?: Error;
}

export class ThreeDErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.warn(`[ThreeDErrorBoundary] 3D Renderer error for ${this.props.minigameId || 'minigame'}, falling back to 2D:`, error, errorInfo);
  }

  public render() {
    if (this.state.hasError) {
      return (
        <div className="relative w-full h-full">
          {/* Subtle Dev Notification */}
          <div className="absolute top-2 right-2 z-50 bg-amber-500/90 text-slate-950 text-xs px-2.5 py-1 rounded-lg font-bold flex items-center gap-1.5 shadow-lg pointer-events-none">
            <AlertTriangle className="w-3.5 h-3.5" />
            <span>3D hiba ➔ 2D fallback aktív</span>
          </div>
          {this.props.fallback}
        </div>
      );
    }

    return this.props.children;
  }
}
