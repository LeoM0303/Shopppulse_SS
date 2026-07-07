import { BrowserRouter, Link, Route, Routes } from "react-router-dom";
import Dashboard from "./pages/Dashboard";
import SubmitEvent from "./pages/SubmitEvent";

export default function App() {
  return (
    <BrowserRouter>
      <nav className="nav">
        <span className="nav-brand">ShopPulse</span>
        <Link to="/">Submit Event</Link>
        <Link to="/dashboard">Dashboard</Link>
      </nav>
      <main className="container">
        <Routes>
          <Route path="/" element={<SubmitEvent />} />
          <Route path="/dashboard" element={<Dashboard />} />
        </Routes>
      </main>
    </BrowserRouter>
  );
}
