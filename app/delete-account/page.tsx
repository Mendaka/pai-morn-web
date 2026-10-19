import type { Metadata } from "next";
import PageShell, { cardClass } from "@/components/PageShell";

export const metadata: Metadata = { title: "Delete Account & Data" };

const EMAIL = "hseng2018@gmail.com";

export default function DeleteAccountPage() {
  return (
    <PageShell title="Delete Your Account & Data" subtitle="How to request deletion of your Paimorn account and data">
      <article className={`${cardClass} space-y-6`}>
        <section>
          <h2 className="text-lg font-bold text-neutral-900">Request full account deletion</h2>
          <ol className="mt-2 list-decimal space-y-1.5 pl-5 leading-relaxed text-neutral-600">
            <li>
              Email <a href={`mailto:${EMAIL}?subject=Delete my account`} className="font-medium text-indigo-600 underline">{EMAIL}</a> from the email
              address linked to your Paimorn account, with the subject &quot;Delete my account&quot;.
            </li>
            <li>We&apos;ll confirm your identity and delete your account within 7 days.</li>
          </ol>
        </section>

        <section>
          <h2 className="text-lg font-bold text-neutral-900">What gets deleted</h2>
          <p className="mt-2 leading-relaxed text-neutral-600">
            Your account, email address, display name, profile photo, draft songs, comments, favorites, setlists, and
            song requests are permanently deleted.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold text-neutral-900">What&apos;s kept</h2>
          <p className="mt-2 leading-relaxed text-neutral-600">
            Songs you submitted that were already approved and published to the public songbook remain visible to
            other users, since they&apos;re shared community content — but they&apos;re unlinked from your account and
            no longer tied to your identity.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-bold text-neutral-900">Delete only some of your data</h2>
          <p className="mt-2 leading-relaxed text-neutral-600">
            You don&apos;t need to delete your whole account for this — inside the app you can already remove your own
            draft songs (My Songs) and your own community posts yourself, any time, without contacting us.
          </p>
        </section>
      </article>
    </PageShell>
  );
}
