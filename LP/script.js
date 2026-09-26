// ==========================
// ELEMENTS
// ==========================

const modal = document.querySelector("#modal");
const modalContent = document.querySelector("#modalContent");
const modalEyebrow = document.querySelector("#modalEyebrow");
const closeBtn = document.querySelector("#closeBtn");

const gformFrame = document.querySelector("#gformFrame");
const formLoading = document.querySelector("#formLoading");

// Every button that should open the modal carries data-open-modal="shopper|retailer"
const openTriggers = document.querySelectorAll("[data-open-modal]");

// ==========================
// GOOGLE FORM LINKS
// ==========================
// Both load inside the modal's <iframe>. Whichever persona the visitor
// picks is the only one that ever gets a src set — the other form is
// never requested, so it stays fully blank/hidden.
//
// Form links use the full docs.google.com/.../viewform address with
// "?embedded=true" appended, which is what makes Google render the
// form cleanly inside an iframe. Every submission still saves straight
// to the Google Sheet linked to each Form.

const FORMS = {

    shopper: {

        url: "https://docs.google.com/forms/d/e/1FAIpQLSeJZrVgg1VgxRqSMdcLAyCtbe2ys2eHG_inzShgwNWxdmrUSg/viewform?embedded=true",
        label: "Shopper Survey"

    },

    retailer: {

        url: "https://docs.google.com/forms/d/e/1FAIpQLSdqs3p2NplxpS8I_yECI8O5Xamd4LFuw2OnVdei331Npx50_w/viewform?embedded=true",
        label: "Retailer Survey"

    }

};

// ==========================
// OPEN / CLOSE MODAL
// ==========================

function openModal(persona){

    const form = FORMS[persona];

    if(!form) return;

    modalContent.classList.remove("mode-shopper","mode-retailer");
    modalContent.classList.add(`mode-${persona}`);

    modalEyebrow.textContent = form.label;

    formLoading.style.display = "flex";
    gformFrame.style.opacity = "0";

    // Only the chosen form is ever loaded into the iframe
    gformFrame.src = form.url;

    modal.style.display = "flex";
    modal.setAttribute("aria-hidden","false");
    document.body.style.overflow = "hidden";

}

function closeModal(){

    modal.style.display = "none";
    modal.setAttribute("aria-hidden","true");
    document.body.style.overflow = "";

    // Clear the src so the form fully unloads between opens
    gformFrame.src = "";

}

openTriggers.forEach(btn => {

    btn.addEventListener("click", () => openModal(btn.dataset.openModal));

});

closeBtn.addEventListener("click", closeModal);

modal.addEventListener("click", (e) => {

    if(e.target === modal) closeModal();

});

document.addEventListener("keydown", (e) => {

    if(e.key === "Escape" && modal.style.display === "flex") closeModal();

});

gformFrame.addEventListener("load", () => {

    if(gformFrame.src){

        formLoading.style.display = "none";
        gformFrame.style.opacity = "1";

    }

});

// ==========================
// SCROLL REVEAL
// ==========================

const revealTargets = document.querySelectorAll(
    "section, .path-card, footer"
);

revealTargets.forEach(el => el.classList.add("reveal"));

const revealObserver = new IntersectionObserver((entries) => {

    entries.forEach(entry => {

        if(entry.isIntersecting){

            entry.target.classList.add("show");
            revealObserver.unobserve(entry.target);

        }

    });

}, { threshold:0.15 });

revealTargets.forEach(el => revealObserver.observe(el));

// ==========================
// NAVBAR ON SCROLL
// ==========================

const nav = document.querySelector("nav");

window.addEventListener("scroll", () => {

    nav.classList.toggle("scrolled", window.scrollY > 40);

});

// ==========================
// CONSOLE SIGNATURE
// ==========================

console.log("TryyLO — your city, your style. Built with care.");

// ==========================
// LOADER
// ==========================

const loader = document.getElementById("loader");
const loaderVideo = document.getElementById("loaderVideo");
const page = document.getElementById("pageContent");

loaderVideo.addEventListener("ended", ()=>{

    page.classList.add("loaded");

    loader.classList.add("hide");

    setTimeout(()=>{
        loader.remove();
    },800);

});
