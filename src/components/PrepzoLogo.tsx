import Image from 'next/image';

interface PrepzoLogoProps {
  className?: string;
  variant?: 'light' | 'dark';
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  showText?: boolean;
  tagline?: string;
  badge?: string;
  priority?: boolean;
}

const sizes = {
  xs: { h: 'h-6', iconH: 'h-6', w: 116, badge: 'text-[8px] px-1.5 py-0.5', tagline: 'text-[8px]' },
  sm: { h: 'h-8', iconH: 'h-8', w: 155, badge: 'text-[8px] px-2 py-0.5', tagline: 'text-[9px]' },
  md: { h: 'h-9', iconH: 'h-9', w: 174, badge: 'text-[9px] px-2.5 py-0.5', tagline: 'text-[10px]' },
  lg: { h: 'h-11', iconH: 'h-11', w: 213, badge: 'text-[10px] px-2.5 py-0.5', tagline: 'text-[11px]' },
  xl: { h: 'h-14', iconH: 'h-14', w: 271, badge: 'text-xs px-3 py-1', tagline: 'text-xs' },
};

export default function PrepzoLogo({
  className = '',
  variant = 'dark',
  size = 'md',
  showText = true,
  tagline,
  badge,
  priority = true,
}: PrepzoLogoProps) {
  const current = sizes[size] || sizes.md;
  const isLight = variant === 'light';

  const logoSrc = showText
    ? (isLight ? '/prepzo-logo-horizontal-white.png' : '/prepzo-logo-horizontal.png')
    : '/prepzo-icon.png';

  const subColor = isLight ? 'text-emerald-300/90' : 'text-[#005C42]/70';

  return (
    <div className={`inline-flex items-center gap-2.5 ${className}`}>
      <div className="flex flex-col">
        <div className="inline-flex items-center gap-2.5">
          <Image
            src={logoSrc}
            alt="Prepzo"
            width={showText ? current.w : 64}
            height={64}
            className={`${showText ? current.h : current.iconH} w-auto object-contain shrink-0`}
            priority={priority}
          />
          {badge && (
            <span className={`rounded-full border border-[#E8A400]/40 bg-[#E8A400]/10 font-extrabold uppercase tracking-wider text-[#B87900] ${current.badge}`}>
              {badge}
            </span>
          )}
        </div>
        {tagline && (
          <span className={`font-bold tracking-widest uppercase mt-1 ${current.tagline} ${subColor}`}>
            {tagline}
          </span>
        )}
      </div>
    </div>
  );
}

