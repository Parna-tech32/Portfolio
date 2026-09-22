"use client";

import { FormEvent, useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const supabase = createClient();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isSignup, setIsSignup] = useState(false);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();

    setLoading(true);
    setMessage("");

    try {
      if (isSignup) {
        const origin = window.location.origin;

        const { data, error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            emailRedirectTo: `${origin}/auth/confirm`,
          },
        });

        console.log("Signup result:", data);

        if (error) {
          setMessage(error.message);
          return;
        }

        setMessage(
          "Account created! Check your email to confirm your account."
        );
      } else {
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });

        if (error) {
          setMessage(error.message);
          return;
        }

        window.location.href = "/";
      }
    } catch (error) {
      console.error("Authentication error:", error);
      setMessage("Something went wrong. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-950 px-6 text-white">
      <div className="w-full max-w-md">

        {/* Header */}
        <div className="mb-8 text-center">
          <div className="text-4xl">✈️</div>

          <h1 className="mt-4 text-3xl font-bold">
            {isSignup ? "Create your account" : "Welcome back"}
          </h1>

          <p className="mt-2 text-slate-400">
            {isSignup
              ? "Start planning your perfect trips."
              : "Log in to access your saved trips."}
          </p>
        </div>

        {/* Form */}
        <form
          onSubmit={handleSubmit}
          className="rounded-3xl border border-slate-800 bg-slate-900 p-8"
        >
          {/* Email */}
          <label className="mb-2 block text-sm text-slate-300">
            Email
          </label>

          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@example.com"
            className="mb-5 w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-white outline-none focus:border-cyan-400"
          />

          {/* Password */}
          <label className="mb-2 block text-sm text-slate-300">
            Password
          </label>

          <input
            type="password"
            required
            minLength={6}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="••••••••"
            className="w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-white outline-none focus:border-cyan-400"
          />

          {/* Submit */}
          <button
            type="submit"
            disabled={loading}
            className="mt-6 w-full rounded-xl bg-cyan-400 py-3 font-semibold text-slate-950 transition hover:bg-cyan-300 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {loading
              ? "Please wait..."
              : isSignup
                ? "Create Account"
                : "Log In"}
          </button>

          {/* Message */}
          {message && (
            <div className="mt-4 rounded-xl bg-slate-800 p-3 text-center text-sm text-slate-300">
              {message}
            </div>
          )}

          {/* Switch Login / Signup */}
          <div className="mt-6 text-center text-sm text-slate-400">
            {isSignup
              ? "Already have an account?"
              : "Don't have an account?"}

            <button
              type="button"
              onClick={() => {
                setIsSignup(!isSignup);
                setMessage("");
              }}
              className="ml-2 font-semibold text-cyan-400 hover:text-cyan-300"
            >
              {isSignup ? "Log in" : "Sign up"}
            </button>
          </div>
        </form>

        {/* Back to Home */}
        <div className="mt-6 text-center">
          <a
            href="/"
            className="text-sm text-slate-500 hover:text-slate-300"
          >
            ← Back to TripAI
          </a>
        </div>

      </div>
    </main>
  );
}