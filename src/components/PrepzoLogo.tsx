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
  sm: { mark: 'h-8 w-8', name: 'text-lg', tagline: 'text-[7px]', badge: 'text-[8px] px-1.5 py-0.5' },
  md: { mark: 'h-10 w-10', name: 'text-2xl', tagline: 'text-[8px]', badge: 'text-[9px] px-2 py-0.5' },
  lg: { mark: 'h-12 w-12', name: 'text-3xl', tagline: 'text-[9px]', badge: 'text-[10px] px-2.5 py-0.5' },
  xl: { mark: 'h-20 w-20', name: 'text-5xl', tagline: 'text-xs', badge: 'text-xs px-3 py-1' },
};

/** The supplied Prepzo mark, cropped to its graduation-cap learning symbol. */
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
  const subColor = variant === 'light' ? 'text-white/75' : 'text-[#31725d]';

  return (
    <div className={`inline-flex items-center gap-2.5 ${className}`}>
      <div className={`${current.mark} relative shrink-0 overflow-hidden rounded-[30%] bg-white`} aria-hidden="true">
        <Image
          src="/prepzo-logo.png"
          alt=""
          fill
          sizes="80px"
          className="absolute !h-auto !w-[190%] !max-w-none left-[-45%] top-[-10%]"
          priority={size === 'xl'}
        />
      </div>
      {showText && (
        <div className="flex min-w-0 flex-col leading-none select-none">
          <div className="flex items-center gap-2">
            <span className={`${current.name} font-black tracking-[-0.07em] ${textColor}`}>
              prep<span className="text-[#E8A400]">zo</span>
            </span>
            {badge && <span className={`rounded-full border border-[#E8A400]/35 bg-[#E8A400]/10 font-extrabold uppercase tracking-wider text-[#B87900] ${current.badge}`}>{badge}</span>}
          </div>
          <span className={`${current.tagline} mt-1 font-bold tracking-[0.08em] ${subColor}`}>
            {tagline || 'smart prep, learn anytime anywhere'}
          </span>
        </div>
      )}
    </div>
  );
}
