import { TopProduct } from "../api/client";

interface Props {
  products: TopProduct[];
}

export default function TopProductsTable({ products }: Props) {
  return (
    <div className="table-card">
      <h2>Top Products (last 24h)</h2>
      <table>
        <thead>
          <tr>
            <th>Rank</th>
            <th>Product Name</th>
            <th>Product ID</th>
            <th>Units Sold</th>
            <th>Revenue</th>
          </tr>
        </thead>
        <tbody>
          {products.map((p, i) => (
            <tr key={p.product_id}>
              <td>{i + 1}</td>
              <td>{p.product_name}</td>
              <td>{p.product_id}</td>
              <td>{p.units_sold}</td>
              <td>${p.revenue.toFixed(2)}</td>
            </tr>
          ))}
          {products.length === 0 && (
            <tr>
              <td colSpan={5} style={{ textAlign: "center", color: "#999" }}>No data</td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
