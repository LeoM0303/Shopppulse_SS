interface Props {
  label: string;
  value: string | number;
}

export default function SalesSummaryCard({ label, value }: Props) {
  return (
    <div className="card">
      <div className="label">{label}</div>
      <div className="value">{value}</div>
    </div>
  );
}
