module ApplicationHelper
  def toast_class(type)
    base = "rounded-lg border px-4 py-3 shadow-sm flex items-center justify-between gap-3 min-w-[280px] max-w-md"
    case type.to_s
    when "notice"
      "#{base} border-emerald-200 bg-emerald-50 text-emerald-800"
    when "alert"
      "#{base} border-rose-200 bg-rose-50 text-rose-800"
    else
      "#{base} border-slate-200 bg-slate-50 text-slate-800"
    end
  end
end
