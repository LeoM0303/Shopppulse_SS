import { useEffect, useState } from "react";
import { getDashboard, DashboardSummary } from "../api/client";
import AlertBanner from "../components/AlertBanner";
import SalesSummaryCard from "../components/SalesSummaryCard";
import TopProductsTable from "../components/TopProductsTable";

export default function Dashboard() {
  const [data, setData] = useState<DashboardSummary | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function fetchData() {
    try {
      const summary = await getDashboard();
      setData(summary);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load dashboard");
    }
  }

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 10_000);
    return () => clearInterval(interval);
  }, []);

  if (error) return <div className="banner error">{error}</div>;
  if (!data) return <p>Loading dashboard…</p>;

  return (
    <div>
      <h1>Dashboard</h1>
      <div className="meta">
        <span>Last updated: {new Date(data.updated_at).toLocaleString()}</span>
        <span className={`badge ${data.source === "db" ? "fallback" : ""}`}>
          {data.source === "cache" ? "LIVE (cache)" : "FALLBACK (db)"}
        </span>
      </div>
      <AlertBanner alerts={data.alerts} />
      <div className="cards">
        <SalesSummaryCard label="Total Sales (24h)" value={data.total_sales} />
        <SalesSummaryCard label="Total Returns (24h)" value={data.total_returns} />
        <SalesSummaryCard label="Net Revenue" value={`$${data.net_revenue.toFixed(2)}`} />
      </div>
      <TopProductsTable products={data.top_products} />
    </div>
  );
}
