"use client";

import Link from "next/link";
import { ArrowLeft, Mail, MessageCircle, Phone, MapPin } from "lucide-react";
import PrepzoLogo from "@/components/PrepzoLogo";

export default function ContactPage() {
  return (
    <main className="min-h-screen bg-[#f7faf7] text-[#004933]">
      <header className="border-b border-[#005c42]/10 bg-white">
        <div className="mx-auto flex h-20 max-w-5xl items-center justify-between px-5 sm:px-8">
          <Link href="/" className="inline-flex items-center gap-2 text-sm font-bold text-[#005c42]">
            <ArrowLeft size={18} /> Back to Prepzo
          </Link>
          <PrepzoLogo variant="dark" size="sm" />
        </div>
      </header>

      <section className="mx-auto max-w-5xl px-5 py-12 sm:px-8 sm:py-20">
        <p className="text-xs font-extrabold uppercase tracking-[.16em] text-[#b27800]">
          We are here to help
        </p>
        <h1 className="mt-3 max-w-2xl text-4xl sm:text-5xl font-black tracking-[-.06em] text-[#004933]">
          Contact Prepzo
        </h1>
        <p className="mt-5 max-w-xl text-base sm:text-lg leading-8 text-[#477663]">
          Whether you need help getting started, have a course query, or want to visit our center, our team is ready to assist.
        </p>

        {/* Contact Cards Grid */}
        <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {/* Call Us */}
          <div className="rounded-3xl border border-[#005c42]/10 bg-white p-6 shadow-sm transition hover:-translate-y-1 hover:shadow-md flex flex-col justify-between">
            <div>
              <div className="w-12 h-12 rounded-2xl bg-[#fff8e5] flex items-center justify-center text-[#e8a400]">
                <Phone size={24} />
              </div>
              <h2 className="mt-5 text-lg font-black text-[#004933]">Call us</h2>
              <p className="mt-1 text-xs text-[#477663]">Direct lines for admissions & support.</p>
            </div>
            <div className="mt-5 space-y-1">
              <a href="tel:+919311623522" className="block font-bold text-sm text-[#005c42] hover:underline">
                +91 93116 23522
              </a>
              <a href="tel:+918796339455" className="block font-bold text-sm text-[#005c42] hover:underline">
                +91 87963 39455
              </a>
            </div>
          </div>

          {/* WhatsApp */}
          <div className="rounded-3xl border border-[#005c42]/10 bg-white p-6 shadow-sm transition hover:-translate-y-1 hover:shadow-md flex flex-col justify-between">
            <div>
              <div className="w-12 h-12 rounded-2xl bg-[#e7f6ee] flex items-center justify-center text-[#005c42]">
                <MessageCircle size={24} />
              </div>
              <h2 className="mt-5 text-lg font-black text-[#004933]">WhatsApp</h2>
              <p className="mt-1 text-xs text-[#477663]">Instant chat with our counselor.</p>
            </div>
            <div className="mt-5 space-y-1">
              <a
                href="https://wa.me/919311623522"
                target="_blank"
                rel="noreferrer"
                className="block font-bold text-sm text-[#005c42] hover:underline"
              >
                +91 93116 23522
              </a>
              <a
                href="https://wa.me/918796339455"
                target="_blank"
                rel="noreferrer"
                className="block font-bold text-sm text-[#005c42] hover:underline"
              >
                +91 87963 39455
              </a>
            </div>
          </div>

          {/* Email */}
          <a
            href="mailto:contact@prepzo.com"
            className="rounded-3xl border border-[#005c42]/10 bg-white p-6 shadow-sm transition hover:-translate-y-1 hover:shadow-md flex flex-col justify-between"
          >
            <div>
              <div className="w-12 h-12 rounded-2xl bg-[#fff8e5] flex items-center justify-center text-[#e8a400]">
                <Mail size={24} />
              </div>
              <h2 className="mt-5 text-lg font-black text-[#004933]">Email us</h2>
              <p className="mt-1 text-xs text-[#477663]">For general queries and documentation.</p>
            </div>
            <div className="mt-5">
              <span className="block font-bold text-sm text-[#005c42]">contact@prepzo.com</span>
            </div>
          </a>

          {/* Office Address */}
          <div className="rounded-3xl border border-[#005c42]/10 bg-white p-6 shadow-sm transition hover:-translate-y-1 hover:shadow-md flex flex-col justify-between">
            <div>
              <div className="w-12 h-12 rounded-2xl bg-[#e7f6ee] flex items-center justify-center text-[#005c42]">
                <MapPin size={24} />
              </div>
              <h2 className="mt-5 text-lg font-black text-[#004933]">Our Center</h2>
              <p className="mt-1 text-xs text-[#477663]">Visit our offline learning center.</p>
            </div>
            <div className="mt-5">
              <p className="font-bold text-xs leading-5 text-[#004933]">
                Unacademy tower, Ipil road number 2, Kota, Rajasthan
              </p>
            </div>
          </div>
        </div>

        {/* Learning Portal CTA Banner */}
        <div className="mt-12 rounded-[2rem] bg-[#005c42] p-8 text-white sm:p-10 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-6">
          <div>
            <h2 className="text-2xl font-black">Already a Prepzo learner?</h2>
            <p className="mt-2 max-w-xl text-sm leading-6 text-white/75">
              For lesson access, attendance, fees or live-class support, sign in so your request reaches your batch mentor directly.
            </p>
          </div>
          <Link
            href="/?login=true"
            className="inline-flex shrink-0 items-center justify-center rounded-full bg-[#e8a400] px-6 py-3.5 font-bold text-[#004933] shadow-md transition hover:bg-[#d69600]"
          >
            Sign in to Prepzo
          </Link>
        </div>
      </section>
    </main>
  );
}

