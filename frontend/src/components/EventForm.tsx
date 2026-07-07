import { useState, FormEvent } from "react";
import { submitEvent, EventPayload } from "../api/client";

const empty: EventPayload = {
  store_id: "",
  product_id: "",
  product_name: "",
  event_type: "sale",
  quantity: 1,
  unit_price: 0,
  occurred_at: undefined,
};

export default function EventForm() {
  const [form, setForm] = useState<EventPayload>(empty);
  const [status, setStatus] = useState<{ type: "success" | "error"; text: string } | null>(null);
  const [loading, setLoading] = useState(false);

  function set(field: keyof EventPayload, value: string | number) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setStatus(null);
    try {
      const payload: EventPayload = {
        ...form,
        occurred_at: form.occurred_at || undefined,
      };
      const result = await submitEvent(payload);
      setStatus({ type: "success", text: `Event created: ${result.id}` });
      setForm(empty);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Unknown error";
      setStatus({ type: "error", text: `Failed to submit event: ${msg}` });
    } finally {
      setLoading(false);
    }
  }

  return (
    <form className="form-card" onSubmit={handleSubmit}>
      <div className="form-grid">
        <div className="form-group">
          <label>Store ID</label>
          <input required value={form.store_id} onChange={(e) => set("store_id", e.target.value)} />
        </div>
        <div className="form-group">
          <label>Product ID</label>
          <input required value={form.product_id} onChange={(e) => set("product_id", e.target.value)} />
        </div>
        <div className="form-group">
          <label>Product Name</label>
          <input required value={form.product_name} onChange={(e) => set("product_name", e.target.value)} />
        </div>
        <div className="form-group">
          <label>Event Type</label>
          <select value={form.event_type} onChange={(e) => set("event_type", e.target.value as "sale" | "return")}>
            <option value="sale">Sale</option>
            <option value="return">Return</option>
          </select>
        </div>
        <div className="form-group">
          <label>Quantity</label>
          <input type="number" required min={1} value={form.quantity} onChange={(e) => set("quantity", Number(e.target.value))} />
        </div>
        <div className="form-group">
          <label>Unit Price (USD)</label>
          <input type="number" required min={0.01} step={0.01} value={form.unit_price} onChange={(e) => set("unit_price", Number(e.target.value))} />
        </div>
        <div className="form-group">
          <label>Occurred At (optional)</label>
          <input type="datetime-local" value={form.occurred_at ?? ""} onChange={(e) => set("occurred_at", e.target.value)} />
        </div>
      </div>
      <div className="form-actions">
        <button type="submit" disabled={loading}>{loading ? "Submitting…" : "Submit Event"}</button>
      </div>
      {status && <div className={`banner ${status.type}`}>{status.text}</div>}
    </form>
  );
}
