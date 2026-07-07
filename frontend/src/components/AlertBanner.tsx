import { Alert } from "../api/client";

interface Props {
  alerts: Alert[];
}

export default function AlertBanner({ alerts }: Props) {
  if (alerts.length === 0) return null;
  return (
    <div style={{ marginBottom: "1rem" }}>
      {alerts.map((a, i) => (
        <div key={i} className={`banner ${a.level === "error" ? "error" : "warning"}`}>
          <strong>{a.level.toUpperCase()}:</strong> {a.message}
        </div>
      ))}
    </div>
  );
}
