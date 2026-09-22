import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import TripsClient from "../../components/TripsClient";

export default async function TripsPage() {
  const supabase = await createClient();

  // Get logged-in user
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // If not logged in, send to login
  if (!user) {
    redirect("/login");
  }

  // Get only this user's trips
  const { data: trips, error } = await supabase
    .from("trips")
    .select("*")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false });

  if (error) {
    return (
      <main className="min-h-screen bg-slate-950 p-8 text-white">
        <h1 className="text-3xl font-bold">
          My Trips
        </h1>

        <p className="mt-4 text-red-400">
          Failed to load trips: {error.message}
        </p>
      </main>
    );
  }

  return <TripsClient trips={trips || []} />;
}