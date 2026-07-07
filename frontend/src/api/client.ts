import axios from "axios";

const BASE_URL = (import.meta.env.VITE_API_BASE_URL as string) || "";

const http = axios.create({ baseURL: BASE_URL });

export interface EventPayload {
  store_id: string;
  product_id: string;
  product_name: string;
  event_type: "sale" | "return";
  quantity: number;
  unit_price: number;
  occurred_at?: string;
}

export interface SalesEvent extends EventPayload {
  id: string;
  created_at: string;
  occurred_at: string;
}

export interface TopProduct {
  product_id: string;
  product_name: string;
  units_sold: number;
  revenue: number;
}

export interface Alert {
  level: "warning" | "error";
  message: string;
}

export interface DashboardSummary {
  updated_at: string;
  period_hours: number;
  total_sales: number;
  total_returns: number;
  net_revenue: number;
  top_products: TopProduct[];
  alerts: Alert[];
  source?: "cache" | "db";
}

export interface EventsQueryParams {
  store_id?: string;
  event_type?: string;
  limit?: number;
  offset?: number;
}

export interface EventsResponse {
  total: number;
  items: SalesEvent[];
}

export async function submitEvent(payload: EventPayload): Promise<SalesEvent> {
  const { data } = await http.post<SalesEvent>("/api/events", payload);
  return data;
}

export async function getDashboard(): Promise<DashboardSummary> {
  const { data } = await http.get<DashboardSummary>("/api/dashboard");
  return data;
}

export async function getEvents(params?: EventsQueryParams): Promise<EventsResponse> {
  const { data } = await http.get<EventsResponse>("/api/events", { params });
  return data;
}
