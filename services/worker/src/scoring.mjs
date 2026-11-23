/**
 * Pure, reproducible, conservative academic rubric.
 * Scores do not estimate interview probability or hiring outcome.
 * Only extracted facts explicitly supported by the CV may be used.
 */
export const EVALUATOR_VERSION = 'ats-match-v0.1';

export function normalizeTerms(values) {
  return [...new Set((Array.isArray(values) ? values : [])
    .map(value => String(value).toLocaleLowerCase().trim())
    .filter(Boolean))];
}

export function evaluate(candidate, requirements) {
  const sections = candidate?.sections ?? {};
  const person = candidate?.candidate ?? {};
  const cvSkills = normalizeTerms(person.skills);
  const required = normalizeTerms(requirements?.required_skills);
  const preferred = normalizeTerms(requirements?.preferred_skills);
  const hasExperience = Array.isArray(person.experience) && person.experience.length > 0;
  const hasEducation = Array.isArray(person.education) && person.education.length > 0;
  const hasEmail = !!person.email;

  const points = {
    contact: hasEmail ? 15 : 0,
    skills_section: sections.skills ? 20 : 0,
    experience_section: sections.experience && hasExperience ? 20 : 0,
    education_section: sections.education && hasEducation ? 15 : 0,
    standard_headings: sections.standard_headings ? 15 : 0,
    selectable_text: sections.selectable_text ? 15 : 0,
  };
  const atsOverall = Object.values(points).reduce((a, b) => a + b, 0);

  const skillMatch = list => list.length ?
    list.filter(skill => cvSkills.includes(skill)).length / list.length : null;
  const reqCoverage = skillMatch(required);
  const prefCoverage = skillMatch(preferred);
  // Do not award artificial perfect scores for job descriptions without skill criteria.
  const weights = [
    ...(reqCoverage === null ? [] : [{weight: 80, value: reqCoverage}]),
    ...(prefCoverage === null ? [] : [{weight: 20, value: prefCoverage}]),
  ];
  const matchOverall = weights.length
    ? Math.round(100 * weights.reduce((sum, x) => sum + x.weight * x.value, 0) /
      weights.reduce((sum, x) => sum + x.weight, 0))
    : null;
  const missingRequired = required.filter(s => !cvSkills.includes(s));
  const missingPreferred = preferred.filter(s => !cvSkills.includes(s));
  const recommendations = [];
  if (!hasEmail) recommendations.push({
    priority: 1, category: 'contact', message: 'Include a readable professional email address.'
  });
  if (!sections.skills) recommendations.push({
    priority: 2, category: 'structure', message: 'Add a clearly labeled skills section.'
  });
  if (!sections.experience) recommendations.push({
    priority: 2, category: 'structure', message: 'Add an experience section, including projects or internships when applicable.'
  });
  if (!sections.selectable_text) recommendations.push({
    priority: 2, category: 'format', message: 'Provide a text-readable version of your CV to improve automated parsing.'
  });
  if (missingRequired.length) recommendations.push({
    priority: 1, category: 'matching',
    message: 'The job description requires: ' + missingRequired.slice(0, 8).join(', ') +
      '. Only mention these skills if you actually have evidence of them.'
  });

  return {
    ats: { overall: atsOverall, rubric: { components: points } },
    match: {
      overall: matchOverall,
      rubric: {
        required_coverage: reqCoverage,
        preferred_coverage: prefCoverage,
        matched_required: required.filter(s => cvSkills.includes(s)),
        missing_required: missingRequired,
        missing_preferred: missingPreferred,
        methodology: 'Exact normalized skill phrase overlap; not an employability prediction.'
      },
    },
    recommendations,
  };
}
