import { ReactNode } from 'react';
import { Link, useLocation } from 'react-router-dom';

const navItems = [
  { path: '/', label: 'Dashboard' },
  { path: '/incidents', label: 'Incidents' },
  { path: '/activity', label: 'Activity Log' },
];

export default function Layout({ children }: { children: ReactNode }) {
  const location = useLocation();

  return (
    <div className="min-h-screen flex flex-col">
      <header className="bg-snow-nav text-white shadow-lg">
        <div className="max-w-7xl mx-auto px-4 flex items-center h-12">
          <div className="flex items-center gap-2 mr-8">
            <div className="w-6 h-6 bg-snow-accent rounded-sm flex items-center justify-center text-snow-nav font-bold text-xs">
              SN
            </div>
            <span className="font-semibold text-sm tracking-wide">SNOW Emulator</span>
          </div>
          <nav className="flex gap-1">
            {navItems.map((item) => (
              <Link
                key={item.path}
                to={item.path}
                className={`px-3 py-1.5 rounded text-sm transition-colors ${
                  location.pathname === item.path
                    ? 'bg-snow-nav-hover text-white'
                    : 'text-gray-300 hover:text-white hover:bg-snow-nav-hover'
                }`}
              >
                {item.label}
              </Link>
            ))}
          </nav>
          <div className="ml-auto text-xs text-gray-400">
            Elastic Security Demo Tool
          </div>
        </div>
      </header>
      <main className="flex-1 max-w-7xl mx-auto w-full px-4 py-6">
        {children}
      </main>
    </div>
  );
}
