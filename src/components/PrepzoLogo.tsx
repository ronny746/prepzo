import Image from 'next/image';

interface PrepzoLogoProps {
  className?: string;
  variant?: 'light' | 'dark';
  size?: 'sm' | 'md' | 'lg' | 'xl';
  showText?: boolean;
  tagline?: string;
  badge?: string;
}

const sizes = {
  sm: { mark: 'h-8 w-8', name: 'text-xl', badge: 'text-[8px] px-1.5 py-0.5' },
  md: { mark: 'h-10 w-10', name: 'text-2xl', badge: 'text-[9px] px-2 py-0.5' },
  lg: { mark: 'h-12 w-12', name: 'text-3xl', badge: 'text-[10px] px-2.5 py-0.5' },
  xl: { mark: 'h-16 w-16', name: 'text-4xl', badge: 'text-xs px-3 py-1' },
};

export default function PrepzoLogo({
  className = '',
  variant = 'dark',
  size = 'md',
  showText = true,
  tagline,
  badge,
}: PrepzoLogoProps) {
  const current = sizes[size];
  const textColor = variant === 'light' ? 'text-white' : 'text-[#005C42]';
  const subColor = variant === 'light' ? 'text-white/80' : 'text-[#005C42]/70';

  return (
    <div className={`inline-flex items-center gap-2.5 ${className}`}>
      <div className={`${current.mark} relative shrink-0 flex items-center justify-center`} aria-hidden="true">
        <Image
          src="/prepzo-icon.png"
          alt="Prepzo"
          width={64}
          height={64}
          className="w-full h-full object-contain"
          priority
        />
      </div>
      {showText && (
        <div className="flex min-w-0 flex-col leading-tight select-none">
          <div className="flex items-center gap-2">
            <span className={`${current.name} font-black tracking-tight ${textColor}`}>
              prep<span className="text-[#E8A400]">zo</span>
            </span>
            {badge && (
              <span className={`rounded-full border border-[#E8A400]/35 bg-[#E8A400]/10 font-extrabold uppercase tracking-wider text-[#B87900] ${current.badge}`}>
                {badge}
              </span>
            )}
          </div>
          {tagline && (
            <span className={`text-[10px] font-semibold tracking-wider uppercase ${subColor}`}>
              {tagline}
            </span>
          )}
        </div>
      )}
    </div>
  );
}
