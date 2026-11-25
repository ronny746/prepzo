"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ArrowRight, BookOpen, CheckCircle2, Clock3, GraduationCap, Search } from "lucide-react";
import PrepzoLogo from "@/components/PrepzoLogo";

type Course = {
  _id: string;
  slug?: string;
  name: string;
  subtitle?: string;
  description?: string;
  fee?: number;
  actualFee?: number;
  duration?: string;
  startDate?: string;
  targetExam?: string;
  targetClass?: string;
  medium?: string;
  badge?: string;
  features?: string[];
  color?: string;
};

const formatFee = (fee?: number) => (Number(fee) > 0 ? `₹${Number(fee).toLocaleString('en-IN')}` : 'Free');

export default function ExploreCoursesPage() {
  const [courses, setCourses] = useState<Course[]>([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetch('/api/v1/public/courses')
      .then(async (res) => {
        const body = await res.json();
        if (!res.ok || !body.success) throw new Error(body.message || 'Unable to load courses');
        setCourses(body.data || []);
      })
      .catch((err) => setError(err.message || 'Unable to load courses'))
      .finally(() => setLoading(false));
  }, []);

  const visibleCourses = courses.filter((course) => {
    const haystack = [course.name, course.subtitle, course.targetExam, course.targetClass, course.medium].filter(Boolean).join(' ').toLowerCase();
    return haystack.includes(query.toLowerCase().trim());
  });

  return (
    <main className="min-h-screen bg-[#f7faf7] text-[#004933]">
      <header className="sticky top-0 z-40 border-b border-[#005c42]/10 bg-[#f7faf7]/95 backdrop-blur">
        <div className="mx-auto flex h-20 max-w-7xl items-center justify-between px-5 sm:px-8">
          <Link href="/" aria-label="Prepzo home"><PrepzoLogo variant="dark" size="lg" /></Link>
          <nav className="flex items-center gap-3 text-sm font-bold">
            <Link href="/" className="hidden rounded-full px-4 py-2 text-[#477663] hover:bg-[#e7f3ec] sm:inline-flex">Home</Link>
            <Link href="/login" className="rounded-full bg-[#005c42] px-5 py-2.5 text-white shadow-[0_10px_24px_rgba(0,92,66,.18)] hover:bg-[#004933]">Sign in</Link>
          </nav>
        </div>
      </header>

      <section className="relative overflow-hidden bg-[#005c42] px-5 py-16 text-white sm:px-8 sm:py-20">
        <div className="absolute -right-24 -top-24 h-80 w-80 rounded-full bg-[#e8a400]/20 blur-3xl" />
        <div className="relative mx-auto max-w-7xl">
          <p className="inline-flex items-center gap-2 rounded-full border border-[#f8c84a]/40 bg-white/10 px-4 py-2 text-xs font-extrabold uppercase tracking-[.16em] text-[#f8c84a]"><GraduationCap size={15} /> Learn with a plan</p>
          <h1 className="mt-6 max-w-3xl text-5xl font-black leading-[.98] tracking-[-.06em] sm:text-6xl">Explore courses built for your next result.</h1>
          <p className="mt-6 max-w-2xl text-lg leading-8 text-white/75">Compare live learning, practice and test-series courses in one place. Open any course to see the full plan before you sign in.</p>
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-5 py-10 sm:px-8">
        <div className="flex flex-col justify-between gap-5 md:flex-row md:items-center">
          <div><p className="text-xs font-extrabold uppercase tracking-[.16em] text-[#b27800]">Course catalogue</p><h2 className="mt-2 text-3xl font-black tracking-[-.04em]">Choose your learning path</h2></div>
          <label className="flex w-full items-center gap-3 rounded-2xl border border-[#005c42]/15 bg-white px-4 py-3 text-[#477663] shadow-sm md:max-w-sm"><Search size={18} /><span className="sr-only">Search courses</span><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search courses, exams, classes…" className="w-full bg-transparent text-sm outline-none placeholder:text-[#89a89b]" /></label>
        </div>

        {loading && <div className="py-20 text-center text-[#477663]">Loading courses…</div>}
        {!loading && error && <div className="mt-8 rounded-2xl border border-red-200 bg-red-50 p-6 text-red-700">{error}</div>}
        {!loading && !error && visibleCourses.length === 0 && <div className="mt-8 rounded-3xl border border-[#005c42]/10 bg-white p-12 text-center"><BookOpen className="mx-auto text-[#e8a400]" size={32} /><p className="mt-4 font-bold">No matching courses yet.</p><p className="mt-2 text-sm text-[#477663]">Try another exam or class name.</p></div>}

        <div className="mt-8 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {visibleCourses.map((course) => {
            const isFree = !Number(course.fee);
            return <article key={course._id} className="group overflow-hidden rounded-[1.75rem] border border-[#005c42]/10 bg-white shadow-[0_14px_35px_rgba(0,92,66,.08)] transition hover:-translate-y-1 hover:shadow-[0_22px_48px_rgba(0,92,66,.14)]">
              <div className="relative bg-gradient-to-br from-[#0b132b] to-[#163f39] p-6 text-white" style={course.color ? { background: `linear-gradient(135deg, ${course.color}, #0b132b)` } : undefined}>
                <div className="flex items-center justify-between gap-3"><span className="rounded-full bg-[#f8c84a] px-3 py-1 text-xs font-black text-[#4f3a00]">{course.targetExam || 'All exams'}</span><span className="rounded-full border border-white/20 bg-white/10 px-3 py-1 text-xs font-bold">{isFree ? 'Free access' : 'Premium'}</span></div>
                <h3 className="mt-8 min-h-[3.5rem] text-2xl font-black leading-tight tracking-[-.04em]">{course.name}</h3>
                <p className="mt-2 line-clamp-2 text-sm leading-6 text-white/70">{course.subtitle || course.description || 'A focused Prepzo learning programme.'}</p>
              </div>
              <div className="p-6">
                <div className="flex flex-wrap gap-2 text-xs font-bold text-[#477663]"><span className="inline-flex items-center gap-1 rounded-full bg-[#f0f8f3] px-3 py-1.5"><Clock3 size={13} /> {course.duration || 'Flexible schedule'}</span>{course.targetClass && <span className="rounded-full bg-[#fff7df] px-3 py-1.5">Class {course.targetClass}</span>}{course.medium && <span className="rounded-full bg-[#f0f8f3] px-3 py-1.5">{course.medium}</span>}</div>
                <ul className="mt-5 space-y-2 text-sm text-[#477663]">{(course.features || ['Structured lessons and practice', 'Progress tracking and support']).slice(0, 2).map((feature) => <li key={feature} className="flex gap-2"><CheckCircle2 className="mt-0.5 shrink-0 text-[#00a36c]" size={16} />{feature}</li>)}</ul>
                <div className="mt-6 flex items-end justify-between gap-3 border-t border-[#005c42]/10 pt-5"><div><p className="text-xs font-bold uppercase tracking-wider text-[#89a89b]">Course fee</p><p className="mt-1 text-2xl font-black text-[#004933]">{formatFee(course.fee)}</p></div><Link href={`/course/${course.slug || course._id}`} className="inline-flex items-center gap-2 rounded-full bg-[#005c42] px-4 py-2.5 text-sm font-bold text-white transition group-hover:bg-[#004933]">Explore <ArrowRight size={16} /></Link></div>
              </div>
            </article>;
          })}
        </div>
      </section>
    </main>
  );
}
