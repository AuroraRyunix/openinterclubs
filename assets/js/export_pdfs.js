// Turns every printed fiche (.page[data-filename]) into its own A4 PDF and
// downloads them together as one ZIP. Runs entirely in the browser, so the
// sheets keep lineups from the user's KBSB login.
import html2canvas from "../vendor/html2canvas-pro.min.js"
import {jsPDF} from "../vendor/jspdf.umd.min.js"
import JSZip from "../vendor/jszip.min.js"

const MARGIN = 10 // mm

async function fichePdf(el) {
  const canvas = await html2canvas(el, {scale: 2, backgroundColor: "#ffffff", logging: false})
  const pdf = new jsPDF({orientation: "landscape", unit: "mm", format: "a4", compress: true})
  const pageW = pdf.internal.pageSize.getWidth() - 2 * MARGIN
  const pageH = pdf.internal.pageSize.getHeight() - 2 * MARGIN
  const ratio = Math.min(pageW / canvas.width, pageH / canvas.height)
  const img = canvas.toDataURL("image/jpeg", 0.9)
  pdf.addImage(img, "JPEG", MARGIN, MARGIN, canvas.width * ratio, canvas.height * ratio, undefined, "FAST")
  return pdf.output("arraybuffer")
}

export const ExportPdfs = {
  mounted() {
    this.el.addEventListener("click", async () => {
      const pages = document.querySelectorAll(".page[data-filename]")
      if (pages.length === 0) return

      const label = this.el.textContent
      this.el.disabled = true

      try {
        const zip = new JSZip()
        let i = 0
        for (const page of pages) {
          this.el.textContent = `PDF ${++i}/${pages.length}…`
          zip.file(page.dataset.filename, await fichePdf(page.querySelector(".fiche")))
        }
        const blob = await zip.generateAsync({type: "blob"})
        const a = document.createElement("a")
        a.href = URL.createObjectURL(blob)
        a.download = this.el.dataset.zip || "fiches.zip"
        a.click()
        setTimeout(() => URL.revokeObjectURL(a.href), 10000)
      } catch (e) {
        console.error(e)
        alert("PDF's maken mislukt: " + e.message)
      } finally {
        this.el.textContent = label
        this.el.disabled = false
      }
    })
  }
}
