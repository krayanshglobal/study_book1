import React from "react";

const LOGO_URL = "/c_maths_logo.png";

export function Logo({ size = 48, showText = true }) {
  return (
    <div className="flex items-center gap-2.5" data-testid="app-logo">
      <img
        src={LOGO_URL}
        alt="C Maths"
        style={{ width: size, height: size }}
        className="rounded-2xl object-contain shadow-[0_8px_24px_-8px_rgba(124,58,237,0.45)]"
      />
      {showText && (
        <span className="font-serif text-[26px] leading-none font-semibold tracking-tight text-[#0F1B4C] hidden sm:inline">
          C <span className="text-[#7C3AED]">Maths</span>
        </span>
      )}
    </div>
  );
}

export const LOGO_URL_EXPORT = LOGO_URL;
export default Logo;

